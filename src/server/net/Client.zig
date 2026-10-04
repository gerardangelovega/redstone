const std = @import("std");
const linux = std.os.linux;
const log = std.log.scoped(.net_client);

const common = @import("common.zig");

/// `Client` abstracts the handling of client connections, reading from and writing
/// to socket buffers
const Client = @This();

socket: i32,

/// Initializes a `Client` struct by setting the `Client` fd to the provided fd
/// referencing a client connection
pub fn init(self: *Client, connection_fd: i32) void {
    std.debug.assert(connection_fd >= 0);

    self.* = .{ .socket = connection_fd };
    log.debug("client connected", .{});
}

/// Deinitializes a `Client` struct by terminating client connection via closing
/// the `Client` fd and sets the `Client` fd to -1
pub fn deinit(self: *Client) void {
    std.debug.assert(self.socket >= 0);

    common.fd_close(self.socket);
    log.debug("client disconnected", .{});

    self.socket = -1;
}
