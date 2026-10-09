// standard library, library, and module imports
const std = @import("std");
const sys = @import("sys");

// file imports
const assert = @import("assert");

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

socket: i32 = -1,
addr: [4]u8 = .{ 0, 0, 0, 0 },
port: u16 = 0,
state: State = .uninitialized,

/// Initializes an existing `Listener` instance.
pub fn init(self: *Listener) void {
    const socket_fd: i32 = sys.linux.socket(
        linux.AF.INET,
        linux.SOCK.STREAM | linux.SOCK.NONBLOCK,
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
    log.debug("created TCP socket: fd={d}", .{socket_fd});

    sys.linux.setsockopt(
        socket_fd,
        linux.SOL.SOCKET,
        linux.SO.REUSEADDR,
        1,
    ) catch |err| switch (err) {
        error.Unexpected => {
            @panic("setsockopt() falied, unexpected error");
        },
    };
    log.debug("set TCP socket options: level=SOL.SOCKET opt=SO.REUSEADDR val=1", .{});

    self.* = .{ .state = .initialized, .socket = socket_fd, .port = 0 };

    log.info("listener initialized", .{});

    assert.expensive(assert_fd_is_nonblock, .{socket_fd});
}

/// Deinitializes a `Listener` instance.
pub fn deinit(self: *Listener) void {
    assert.cheap(self.state != .closed);
    assert.cheap(self.state != .uninitialized);
    assert.cheap(self.socket >= 0);

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

/// Binds the `Listener` instance's non-blocking TCP socket to the provided address and
/// port.
pub fn bind(self: *Listener, addr: [4]u8, port: u16) void {
    assert.cheap(self.state == .initialized);

    const socket_address: linux.sockaddr.in = .{
        .family = linux.AF.INET,
        .port = std.mem.nativeTo(u16, port, .big),
        .addr = @bitCast(addr),
    };
    sys.linux.bind(self.socket, &socket_address) catch |err| switch (err) {
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

/// Configures the `Listener` instance's non-blocking TCP socket to listen for
/// connection requests from its bound address and port.
pub fn listen(self: *Listener) void {
    assert.cheap(self.state == .bound);

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

/// Accepts a connection request from the `Listener` instance's TCP socket and returns
/// a file descriptor referencing the client connection.
///
/// Returns the following:
/// - an `i32` value representing an `fd` when a connection request has been
/// accepted.
/// - a `null` if no connection was accepted.
pub fn accept(self: *Listener) ?i32 {
    assert.cheap(self.state == .listening);

    const connection_fd: i32 = sys.linux.accept4(
        self.socket,
        null,
        linux.SOCK.NONBLOCK,
    ) catch |err| switch (err) {
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
    log.debug("accepted client connection: client_fd={d}", .{connection_fd});

    assert.expensive(assert_fd_is_nonblock, .{connection_fd});

    return connection_fd;
}

/// Debug only assertion callback to assert that an fd is set to non-blocking.
fn assert_fd_is_nonblock(fd: i32) bool {
    const flags: u32 = sys.linux.fcntl(fd, linux.F.GETFL, 0) catch |err| switch (err) {
        error.Unexpected => {
            @panic("fcntl(F_GETFL) failed: unexpected error");
        },
    };
    const nonblock: u32 = @bitCast(linux.O{ .NONBLOCK = true });
    return (flags & nonblock) != 0;
}
