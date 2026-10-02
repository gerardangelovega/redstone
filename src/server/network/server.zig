const std = @import("std");
const linux = std.os.linux;

const log = @import("../logging.zig").server;

/// `Server` is an abstraction and encapsulation of data, socket operations, and file
/// descriptor operations that compose a Server
pub const Server = struct {
    pub const State = enum {
        uninitialized,
        initialized,
        bound,
        listening,
        closed,
    };

    state: State = .uninitialized,
    socket: i32 = -1,
    port: u16 = 0,

    /// Initializes the `Server` struct by creating and configuring a non-blocking TCP
    /// socket and setting the `Server` state to `.initialized`
    pub fn init(self: *Server) !void {
        var rv: usize = undefined;

        log.debug("Creating TCP Socket...", .{});
        rv = linux.socket(
            linux.AF.INET,
            linux.SOCK.STREAM,
            linux.IPPROTO.TCP,
        );
        const fd: i32 = switch (linux.errno(rv)) {
            .SUCCESS => blk: {
                log.debug("Successfully created TCP Socket", .{});
                break :blk @intCast(rv);
            },
            else => |errno| {
                log.err("socket() failed: {s}", .{@tagName(errno)});
                return error.SocketFailed;
            },
        };

        log.debug("Getting TCP Socket flags...", .{});
        rv = linux.fcntl(fd, linux.F.GETFL, 0);
        const flags: u32 = switch (linux.errno(rv)) {
            .SUCCESS => blk: {
                log.debug("Successfully got TCP Socket flags", .{});
                break :blk @intCast(rv);
            },
            else => |errno| {
                log.err(
                    "fcntl(F.GETFL) failed, failed to get file descriptor flags: {s}",
                    .{@tagName(errno)},
                );
                return error.FcntlFailed;
            },
        };

        log.debug("Setting TCP Socket to non-blocking...", .{});
        const nonblock: u32 = @bitCast(linux.O{ .NONBLOCK = true });
        rv = linux.fcntl(fd, linux.F.SETFL, flags | nonblock);
        switch (linux.errno(rv)) {
            .SUCCESS => {
                log.debug(
                    "Successfully set TCP Socket to non-blocking",
                    .{},
                );
            },
            else => |errno| {
                log.err(
                    "fcntl(F.SETFl) failed, failed to set file descriptor flags: {s}",
                    .{@tagName(errno)},
                );
                return error.FcntlFailed;
            },
        }

        self.* = .{
            .state = .initialized,
            .socket = fd,
            .port = 0,
        };
    }

    /// Deinitializes the `Server` struct by closing the file descriptor referencing the
    /// non-blocking TCP socket and setting the `Server` state to `.closed` and the
    /// `Server` socket to -1
    pub fn deinit(self: *Server) void {
        std.debug.assert(self.state != .closed);
        std.debug.assert(self.state != .uninitialized);

        log.debug("Closing TCP Socket...", .{});
        _ = linux.close(self.socket);
        log.debug("TCP Socket closed", .{});

        self.socket = -1;
        self.state = .closed;
    }

    /// Binds the `Server` non-blocking TCP socket to a wildcard address (0.0.0.0) and
    /// to the specified port and sets the `Server` state to `.bound`
    pub fn bind(self: *Server, port: u16) !void {
        std.debug.assert(self.state == .initialized);

        var rv: usize = undefined;

        log.debug("Binding TCP Socket to an address and port...", .{});
        const address: linux.sockaddr.in = .{
            .family = linux.AF.INET,
            .port = std.mem.nativeTo(u16, port, .big),
            .addr = 0,
        };
        rv = linux.bind(self.socket, @ptrCast(&address), @sizeOf(linux.sockaddr.in));
        switch (linux.errno(rv)) {
            .SUCCESS => {
                log.debug("Successfully bound TCP Socket to an address and port", .{});
            },
            else => |errno| {
                log.err(
                    "bind() failed on port {d}: {s}",
                    .{ port, @tagName(errno) },
                );
                return error.BindFailed;
            },
        }

        self.state = .bound;
        self.port = port;
    }

    /// Configures the `Server` non-blocking TCP socket to listen for connections in
    /// its bound address and port and sets the `Server` state to `.listening`
    pub fn listen(self: *Server) !void {
        std.debug.assert(self.state == .bound);

        var rv: usize = undefined;

        log.debug("Setting TCP Socket to listen for connections...", .{});
        rv = linux.listen(self.socket, linux.SOMAXCONN);
        switch (linux.errno(rv)) {
            .SUCCESS => {
                log.debug(
                    "Successfully setup TCP Socket to listen for connections",
                    .{},
                );
            },
            else => |errno| {
                log.err("listen() failed: {s}", .{@tagName(errno)});
                return error.ListenFailed;
            },
        }

        self.state = .listening;
    }

    /// Accepts a client requesting a connection to the `Server` socket and returns
    /// a file descriptor that references said client connection
    pub fn accept(self: *Server) !i32 {
        std.debug.assert(self.state == .listening);

        var rv: usize = undefined;

        var client: linux.sockaddr.in = undefined;
        var client_len: linux.socklen_t = @sizeOf(linux.sockaddr.in);

        rv = linux.accept(self.socket, @ptrCast(&client), &client_len);
        const client_fd: i32 = switch (linux.errno(rv)) {
            .SUCCESS => blk: {
                log.debug("Accepted client connection (fd {d})", .{rv});
                break :blk @intCast(rv);
            },
            .INTR, .CONNABORTED, .AGAIN => {
                return error.RetryAccept;
            },
            else => |errno| {
                log.err(
                    "accept() failed, failed to accept client connection: {s}",
                    .{@tagName(errno)},
                );
                return error.AcceptFailed;
            },
        };

        return client_fd;
    }
};
