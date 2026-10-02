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
        defer client.deinit();
    }
}
