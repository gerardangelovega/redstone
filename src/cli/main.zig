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

    _ = request(fd, "hello");
}

fn request(fd: i32, message: []const u8) bool {
    if (message.len > 4096) {
        std.log.warn("message is too long", .{});
        return false;
    }

    var write_buffer: [4 + 4096]u8 = undefined;
    std.mem.writeInt(u32, write_buffer[0..4], @intCast(message.len), .big);
    @memcpy(write_buffer[4 .. 4 + message.len], message);

    var total = 4 + message.len;
    if (!shared.io.blocking.write(fd, write_buffer[0..total])) {
        std.log.warn("write() failed", .{});
        return false;
    }

    var read_buffer: [4 + 4096]u8 = undefined;
    switch (shared.io.blocking.read(fd, read_buffer[0..4])) {
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

    total = len + 4;
    switch (shared.io.blocking.read(fd, read_buffer[4..total])) {
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

    std.log.info("Server: {s}", .{read_buffer[4 .. len + 4]});

    return true;
}

// fn read_full(fd: i32, buffer: []u8) bool {
//     var offset: usize = 0;
//     while (offset < buffer.len) {
//         const rv: usize = linux.read(fd, buffer.ptr + offset, buffer.len - offset);
//         switch (linux.errno(rv)) {
//             .SUCCESS => {
//                 if (rv == 0) {
//                     std.log.warn("EOF", .{});
//                     return false;
//                 }
//             },
//             .INTR => continue,
//             else => return false,
//         }
//         std.debug.assert(rv <= buffer.len - offset);
//         offset = offset + rv;
//     }
//     return true;
// }
//
// fn write_all(fd: i32, buffer: []u8) bool {
//     var offset: usize = 0;
//     while (offset < buffer.len) {
//         const rv: usize = linux.write(fd, buffer.ptr + offset, buffer.len - offset);
//         switch (linux.errno(rv)) {
//             .SUCCESS => {
//                 if (rv == 0) {
//                     std.log.warn("EOF", .{});
//                     return false;
//                 }
//             },
//             .INTR => continue,
//             else => return false,
//         }
//         std.debug.assert(rv <= buffer.len - offset);
//         offset = offset + rv;
//     }
//     return true;
// }
