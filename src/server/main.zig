const std = @import("std");
const linux = std.os.linux;

const network = @import("network.zig");
const logging = @import("logging.zig");

pub fn main(_: std.process.Init) !void {
    std.log.info("Starting server...", .{});

    var server: network.Server = undefined;
    try server.init();
    defer server.deinit();

    try server.bind(6767);
    try server.listen();

    std.log.info("Server listening on port {d}", .{server.port});

    while (true) {
        const client_fd: i32 = server.accept() catch |err| switch (err) {
            error.RetryAccept => continue,
            else => return err,
        };
        var client: network.Client = undefined;
        client.init(client_fd);
        response(&client);
        defer client.deinit();
    }
}

fn response(client: *network.Client) void {
    var buffer: [64]u8 = undefined;
    const rv: usize = linux.read(client.fd, &buffer, buffer.len);
    switch (linux.errno(rv)) {
        .SUCCESS => {
            if (rv == 0) return;
        },
        else => |errno| {
            std.log.err("read() failed to read {s}", .{@tagName(errno)});
            return;
        },
    }
    std.log.debug("Client says: {s}", .{buffer[0..rv]});

    const message: []const u8 = "world";
    _ = linux.write(client.fd, message.ptr, message.len);
}
