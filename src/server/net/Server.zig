const std = @import("std");
const linux = std.os.linux;
const log = std.log.scoped(.net_server);

const common = @import("common.zig");

/// `Server` is an abstraction and encapsulation of data, socket operations, and file
/// descriptor operations that compose a Server
const Server = @This();

const State = enum {
    uninitialized,
    initialized,
    bound,
    listening,
    closed,
};

state: State = .uninitialized,
socket: i32 = -1,
addr: [4]u8 = .{ 0, 0, 0, 0 },
port: u16 = 0,

/// Initializes the `Server` struct by creating and configuring a non-blocking TCP
/// socket and setting the `Server` state to `.initialized`
pub fn init(self: *Server) void {
    var rv: usize = linux.socket(
        linux.AF.INET,
        linux.SOCK.STREAM,
        linux.IPPROTO.TCP,
    );
    const fd: i32 = switch (linux.errno(rv)) {
        .SUCCESS => @intCast(rv),
        .MFILE => {
            log.err("socket() failed: MFILE, process fd limit reached", .{});
            std.process.exit(1);
        },
        .NFILE => {
            log.err("socket() failed: NFILE, system fd limit reached", .{});
            std.process.exit(1);
        },
        .NOBUFS => {
            log.err("socket() failed: NOBUFS, insufficient socket buffer", .{});
            std.process.exit(1);
        },
        .NOMEM => {
            log.err("socket() failed: NOMEM, insufficient memory", .{});
            std.process.exit(1);
        },
        else => |errno| {
            log.err("socket() failed: errno={s}", .{@tagName(errno)});
            @panic("socket() failed");
        },
    };
    log.debug("created TCP socket: fd={d}", .{fd});

    const value: c_int = 1;
    rv = linux.setsockopt(
        fd,
        linux.SOL.SOCKET,
        linux.SO.REUSEADDR,
        &std.mem.toBytes(value),
        @sizeOf(c_int),
    );
    switch (linux.errno(rv)) {
        .SUCCESS => {},
        else => |errno| {
            log.err("setsockopt() failed: fd={d} errno={s}", .{ fd, @tagName(errno) });
            @panic("setsockopt() failed");
        },
    }
    log.debug(
        "set TCP socket options: level=SOL.SOCKET opt=SO.REUSEADDR val={d}",
        .{value},
    );

    common.fd_nonblocking(fd);

    self.* = .{ .state = .initialized, .socket = fd, .port = 0 };
    log.info("server initialized", .{});
}

/// Deinitializes the `Server` struct by closing the file descriptor referencing
/// the non-blocking TCP socket and setting the `Server` state to `.closed`
/// and the `Server` socket to -1
pub fn deinit(self: *Server) void {
    std.debug.assert(self.state != .closed);
    std.debug.assert(self.state != .uninitialized);
    std.debug.assert(self.socket >= 0);

    common.fd_close(self.socket);

    self.socket = -1;
    self.state = .closed;
    log.info("server dinitialized", .{});
}

/// Binds the `Server` non-blocking TCP socket to a wildcard address (0.0.0.0) and
/// to the specified port and sets the `Server` state to `.bound`
pub fn bind(self: *Server, addr: [4]u8, port: u16) void {
    std.debug.assert(self.state == .initialized);

    const address: linux.sockaddr.in = .{
        .family = linux.AF.INET,
        .port = std.mem.nativeTo(u16, port, .big),
        .addr = @bitCast(addr),
    };
    const rv: usize = linux.bind(
        self.socket,
        @ptrCast(&address),
        @sizeOf(linux.sockaddr.in),
    );
    switch (linux.errno(rv)) {
        .SUCCESS => {},
        .ACCES => {
            log.err(
                "bind() failed: ACCES, permission denied for {d}.{d}.{d}.{d}:{d}",
                .{ addr[0], addr[1], addr[2], addr[3], port },
            );
            std.process.exit(1);
        },
        .ADDRINUSE => {
            log.err(
                "bind() failed: ADDRINUSE, {d}.{d}.{d}.{d}:{d} is in use",
                .{ addr[0], addr[1], addr[2], addr[3], port },
            );
            std.process.exit(1);
        },
        .ADDRNOTAVAIL => {
            log.err(
                "bind() failed: ADDRNOTAVAIL, {d}.{d}.{d}.{d}:{d} is unavailable",
                .{ addr[0], addr[1], addr[2], addr[3], port },
            );
            std.process.exit(1);
        },
        else => |errno| {
            log.err("bind() failed: errno={s}", .{@tagName(errno)});
            @panic("bind() failed");
        },
    }
    log.debug(
        "bound TCP socket: fd={d} addr={d}.{d}.{d}.{d}:{d}",
        .{ self.socket, addr[0], addr[1], addr[2], addr[3], port },
    );

    self.state = .bound;
    self.addr = addr;
    self.port = port;
    log.info(
        "server bound to {d}.{d}.{d}.{d}:{d}",
        .{ addr[0], addr[1], addr[2], addr[3], port },
    );
}

/// Configures the `Server` non-blocking TCP socket to listen for connections in
/// its bound address and port and sets the `Server` state to `.listening`
pub fn listen(self: *Server) void {
    std.debug.assert(self.state == .bound);

    const rv: usize = linux.listen(self.socket, linux.SOMAXCONN);
    switch (linux.errno(rv)) {
        .SUCCESS => {},
        .ADDRINUSE => {
            log.err(
                "listen() failed: ADDRINUSE, {d}.{d}.{d}.{d}:{d} is in use",
                .{ self.addr[0], self.addr[1], self.addr[2], self.addr[3], self.port },
            );
            std.process.exit(1);
        },
        else => |errno| {
            log.err(
                "listen() failed: port={d} errno={s}",
                .{ self.port, @tagName(errno) },
            );
            @panic("listen() failed");
        },
    }
    log.debug(
        "listening for connections: fd={d} addr={d}.{d}.{d}.{d}:{d}",
        .{
            self.socket,
            self.addr[0],
            self.addr[1],
            self.addr[2],
            self.addr[3],
            self.port,
        },
    );

    self.state = .listening;
    log.info(
        "server listening for connections on {d}.{d}.{d}.{d}:{d}",
        .{ self.addr[0], self.addr[1], self.addr[2], self.addr[3], self.port },
    );
}

/// Accepts a client requesting a connection to the `Server` socket and returns
/// a file descriptor that references said client connection.
///
/// Returns an `i32` representing an `fd` when a connection has been successfully
/// accepted, returns `null` if no connection was accepted.
pub fn accept(self: *Server) ?i32 {
    std.debug.assert(self.state == .listening);

    const rv: usize = linux.accept(self.socket, null, null);
    const client_fd: i32 = switch (linux.errno(rv)) {
        .SUCCESS => @intCast(rv),
        .INTR, .CONNABORTED, .AGAIN => {
            // INTR         syscall was interrupted by a signal
            // CONNABORTED  connection was terminated before it could be accepted
            // AGAIN        no connections to be accepted
            return null;
        },
        .MFILE => {
            log.warn("accept() failed: MFILE, process fd limit reached", .{});
            return null;
        },
        .NFILE => {
            log.warn("accept() failed: NFILE, system fd limit reached", .{});
            return null;
        },
        .NOBUFS => {
            log.warn("accept() failed: NOBUFS, insufficient socket buffer", .{});
            return null;
        },
        .NOMEM => {
            log.warn("accpet() failed: NOMEM, insufficient memory", .{});
            return null;
        },
        else => |errno| {
            log.err("accept() failed: errno={s}", .{@tagName(errno)});
            @panic("accept() failed");
        },
    };
    log.debug("accepted client connection: client_fd={d}", .{client_fd});

    common.fd_nonblocking(client_fd);

    return client_fd;
}
