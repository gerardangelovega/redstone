const std = @import("std");
const linux = std.os.linux;
const log = std.log.scoped(.net_common);

pub fn fd_nonblocking(fd: i32) void {
    std.debug.assert(fd >= 0);

    var rv: usize = linux.fcntl(fd, linux.F.GETFL, 0);
    const flags: u32 = switch (linux.errno(rv)) {
        .SUCCESS => @intCast(rv),
        else => |errno| {
            log.err(
                "fcntl(GETFL) failed: fd={d} errno={s}",
                .{ fd, @tagName(errno) },
            );
            @panic("fcntl(GETFL) failed");
        },
    };

    const nonblock: u32 = @bitCast(linux.O{ .NONBLOCK = true });
    rv = linux.fcntl(fd, linux.F.SETFL, flags | nonblock);
    switch (linux.errno(rv)) {
        .SUCCESS => {},
        else => |errno| {
            log.err(
                "fcntl(SETFL) failed: fd={d} errno={s}",
                .{ fd, @tagName(errno) },
            );
            @panic("fcntl(SETFL) failed");
        },
    }
    log.debug("set fd to nonblocking: fd={d} flags=(...|O.NONBLOCK)", .{fd});
}

pub fn fd_close(fd: i32) void {
    std.debug.assert(fd >= 0);

    const rv: usize = linux.close(fd);
    switch (linux.errno(rv)) {
        .SUCCESS, .INTR => {},
        .BADF => {
            log.err(
                "close() failed: BADF, closed an invalid or closed fd, fd={d}",
                .{fd},
            );
            @panic("close() failed");
        },
        else => |errno| {
            log.err("close() failed: fd={d} errno={s}", .{ fd, @tagName(errno) });
            return;
        },
    }
    log.debug("closed fd: fd={d}", .{fd});
}
