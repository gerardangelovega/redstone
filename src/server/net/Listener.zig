// standard library, library, and module imports
const std = @import("std");
const sys = @import("sys");

// file imports
const common = @import("common.zig");

// aliases
const linux = std.os.linux;
const log = std.log.scoped(.net_listener);
const posix = std.posix;

/// `Listener` is an abstraction and encapsulation of data, socket operations, and file
/// descriptor operations that compose a Listener
const Listener = @This();

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

/// Initializes the `Listener` struct by creating and configuring a non-blocking TCP
/// socket and setting the `Listener` state to `.initialized`
pub fn init(self: *Listener) void {
    const fd: i32 = sys.linux.socket(
        linux.AF.INET,
        linux.SOCK.STREAM,
        linux.IPPROTO.TCP,
    ) catch |err| switch (err) {
        error.ProcessFdLimitExceeded => {
            const process_limit: ?posix.rlimit = posix.getrlimit(.NOFILE) catch null;
            if (process_limit) |pl| {
                log.err("socket() failed, {}: process limit is {d}", .{ err, pl.max });
            } else {
                log.err("socket() failed, {}: process limit is ?", .{err});
            }
            std.process.exit(1);
        },
        error.SystemFdLimitExceeded => {
            log.err("socket() failed, {}: check /proc/sys/fs/file-max", .{err});
            std.process.exit(1);
        },
        error.SystemResourcesExhausted => {
            log.err("socket() failed, {}: memory/socket buffers full", .{err});
            std.process.exit(1);
        },
        error.Unexpected => {
            @panic("socket() falied, unexpected error");
        },
    };
    log.debug("created TCP socket: fd={d}", .{fd});

    sys.linux.setsockopt(
        fd,
        linux.SOL.SOCKET,
        linux.SO.REUSEADDR,
        1,
    ) catch |err| switch (err) {
        error.Unexpected => {
            @panic("setsockopt() falied, unexpected error");
        },
    };
    log.debug("set TCP socket options: level=SOL.SOCKET opt=SO.REUSEADDR val=1", .{});

    common.fd_nonblocking(fd) catch |err| switch (err) {
        error.Unexpected => {
            @panic("fd_nonblocking() failed, unexpected error");
        },
    };

    self.* = .{ .state = .initialized, .socket = fd, .port = 0 };

    log.info("listener initialized", .{});
}

/// Deinitializes the `Listener` struct by closing the file descriptor referencing
/// the non-blocking TCP socket and setting the `Listener` state to `.closed`
/// and the `Listener` socket to -1
pub fn deinit(self: *Listener) void {
    std.debug.assert(self.state != .closed);
    std.debug.assert(self.state != .uninitialized);
    std.debug.assert(self.socket >= 0);

    sys.linux.close(self.socket) catch |err| switch (err) {
        error.Interrupted => {},
        error.Unexpected => {
            @panic("close() failed, unexpected error");
        },
    };
    log.debug("closed TCP socket: fd{d}", .{self.socket});

    self.socket = -1;
    self.state = .closed;

    log.info("listener dinitialized", .{});
}

/// Binds the `Listener` non-blocking TCP socket to a wildcard address (0.0.0.0) and
/// to the specified port and sets the `Listener` state to `.bound`
pub fn bind(self: *Listener, addr: [4]u8, port: u16) void {
    std.debug.assert(self.state == .initialized);

    const address: linux.sockaddr.in = .{
        .family = linux.AF.INET,
        .port = std.mem.nativeTo(u16, port, .big),
        .addr = @bitCast(addr),
    };
    sys.linux.bind(self.socket, &address) catch |err| switch (err) {
        error.PermissionDenied, error.AddressInUse, error.AddressNotAvailable => {
            log.err(
                "bind() failed, {}: address={d}.{d}.{d}.{d}:{d}",
                .{ err, addr[0], addr[1], addr[2], addr[3], port },
            );
            std.process.exit(1);
        },
        error.Unexpected => {
            @panic("bind() failed, unexpected error");
        },
    };
    log.debug(
        "bound TCP socket: fd={d} addr={d}.{d}.{d}.{d}:{d}",
        .{ self.socket, addr[0], addr[1], addr[2], addr[3], port },
    );

    self.state = .bound;
    self.addr = addr;
    self.port = port;

    log.info(
        "listener bound to {d}.{d}.{d}.{d}:{d}",
        .{ addr[0], addr[1], addr[2], addr[3], port },
    );
}

/// Configures the `Listener` non-blocking TCP socket to listen for connections in
/// its bound address and port and sets the `Listener` state to `.listening`
pub fn listen(self: *Listener) void {
    std.debug.assert(self.state == .bound);

    const addr = self.addr;
    const port = self.port;
    sys.linux.listen(self.socket, linux.SOMAXCONN) catch |err| switch (err) {
        error.AddressInUse => {
            log.err(
                "listen() failed, {}: address={d}.{d}.{d}.{d}:{d}",
                .{ err, addr[0], addr[1], addr[2], addr[3], port },
            );
            std.process.exit(1);
        },
        error.Unexpected => {
            @panic("listen() failed, unexpected error");
        },
    };
    log.debug(
        "listening for connections: fd={d} addr={d}.{d}.{d}.{d}:{d}",
        .{ self.socket, addr[0], addr[1], addr[2], addr[3], port },
    );

    self.state = .listening;

    log.info(
        "listener listening for connections on {d}.{d}.{d}.{d}:{d}",
        .{ addr[0], addr[1], addr[2], addr[3], port },
    );
}

/// Accepts a client requesting a connection to the `Listener` socket and returns
/// a file descriptor that references said client connection.
///
/// Returns an `i32` representing an `fd` when a connection has been successfully
/// accepted, returns `null` if no connection was accepted.
pub fn accept(self: *Listener) ?i32 {
    std.debug.assert(self.state == .listening);

    const fd: i32 = sys.linux.accept(self.socket, null) catch |err| switch (err) {
        error.Interrupted, error.WouldBlock, error.ConnectionAborted => {
            return null;
        },
        error.ProcessFdLimitExceeded => {
            const process_limit: ?posix.rlimit = posix.getrlimit(.NOFILE) catch null;
            if (process_limit) |pl| {
                log.err("socket() failed, {}: process limit is {d}", .{ err, pl.max });
            } else {
                log.err("socket() failed, {}: process limit is ?", .{err});
            }
            std.process.exit(1);
        },
        error.SystemFdLimitExceeded => {
            log.err("accept() failed, {}: check /proc/sys/fs/file-max", .{err});
            std.process.exit(1);
        },
        error.SystemResourcesExhausted => {
            log.err("accept() failed, {}: memory/socket buffers full", .{err});
            std.process.exit(1);
        },
        error.Unexpected => {
            @panic("accept() falied, unexpected error");
        },
    };
    log.debug("accepted client connection: client_fd={d}", .{fd});

    common.fd_nonblocking(fd) catch |err| switch (err) {
        error.Unexpected => {
            @panic("fd_nonblocking() failed, unexpected error");
        },
    };

    return fd;
}
