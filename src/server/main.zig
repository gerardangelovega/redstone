const std = @import("std");
const linux = std.os.linux;
const shared = @import("shared");

const net = @import("net.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main(_: std.process.Init) !void {
    var server: net.Server = undefined;
    server.init();
    defer server.deinit();

    server.bind([4]u8{ 0, 0, 0, 0 }, 6767);
    server.listen();

    while (true) {
        const client_fd: i32 = server.accept() orelse continue;

        var client: net.Client = undefined;
        client.init(client_fd);
        defer client.deinit();

        while (true) {
            const ok: bool = process_request(&client);
            if (!ok) break;
        }
    }
}

fn process_request(client: *net.Client) bool {
    var read_buffer: [4 + 4096]u8 = undefined;
    switch (shared.io.blocking.read(client.socket, read_buffer[0..4])) {
        .ok => {},
        .eof => {
            std.log.debug("client disconnected: res=eof", .{});
            return false;
        },
        .failed => {
            std.log.warn("read_full() failed: res=failed", .{});
            return false;
        },
    }

    const len: u32 = std.mem.readInt(u32, read_buffer[0..4], .big);
    if (len > 4096) {
        std.log.warn("message is too long: len={d}", .{len});
        return false;
    }

    const total = len + 4;
    switch (shared.io.blocking.read(client.socket, read_buffer[4..total])) {
        .ok => {},
        .eof => {
            std.log.debug("client disconnected: res=eof", .{});
            return false;
        },
        .failed => {
            std.log.warn("read_full() failed: res=failed", .{});
            return false;
        },
    }

    std.log.info("Client: {s}", .{read_buffer[4 .. len + 4]});

    const response = "world";
    var write_buffer: [4 + response.len]u8 = undefined;
    std.mem.writeInt(u32, write_buffer[0..4], response.len, .big);
    @memcpy(write_buffer[4..], response);

    return shared.io.blocking.write(client.socket, &write_buffer);
}
