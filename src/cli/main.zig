const std = @import("std");
const linux = std.os.linux;

const shared = @import("shared");

pub fn main(_: std.process.Init) !void {
    var rv: usize = 0;

    const fd: i32 = @intCast(
        linux.socket(
            linux.AF.INET,
            linux.SOCK.STREAM,
            linux.IPPROTO.TCP,
        ),
    );
    switch (linux.errno(rv)) {
        .SUCCESS => {},
        else => |errno| {
            std.log.err(
                "socket() failed: {s}",
                .{@tagName(errno)},
            );
            return error.SocketFailed;
        },
    }
    defer _ = linux.close(fd);

    const address: linux.sockaddr.in = .{
        .family = linux.AF.INET,
        .port = std.mem.nativeTo(u16, 6767, .big),
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };
    rv = linux.connect(fd, @ptrCast(&address), @sizeOf(linux.sockaddr.in));
    switch (linux.errno(rv)) {
        .SUCCESS => {},
        else => |errno| {
            std.log.err(
                "connect() failed: {s}",
                .{@tagName(errno)},
            );
            return error.ConnectFailed;
        },
    }

    request(fd);
}

fn request(fd: i32) void {
    const message: []const u8 = "hello";
    _ = linux.write(fd, message.ptr, message.len);

    var buffer: [64]u8 = undefined;
    const rv: usize = linux.read(fd, &buffer, buffer.len);
    switch (linux.errno(rv)) {
        .SUCCESS => {
            if (rv == 0) return;
        },
        else => |errno| {
            std.log.err("read() failed to read {s}", .{@tagName(errno)});
            return;
        },
    }
    std.log.debug("Server says: {s}", .{buffer[0..rv]});
}
