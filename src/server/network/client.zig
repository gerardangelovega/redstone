const std = @import("std");
const linux = std.os.linux;

const log = @import("../logging.zig").client;

pub const Client = struct {
    fd: i32,

    /// Initializes a `Client` struct by setting the `Client` fd to the provided fd
    /// referencing a client connection
    pub fn init(self: *Client, connection_fd: i32) void {
        self.* = .{
            .fd = connection_fd,
        };
        log.info("Client connection (fd {d}) established", .{self.fd});
    }

    /// Deinitializes a `Client` struct by terminating client connection via closing the
    /// `Client` fd and sets the `Client` fd to -1
    pub fn deinit(self: *Client) void {
        _ = linux.close(self.fd);
        log.info("Client connection (fd {d}) closed", .{self.fd});

        self.fd = -1;
    }
};
