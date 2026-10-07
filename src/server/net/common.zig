const std = @import("std");
const sys = @import("sys");

const linux = std.os.linux;
const log = std.log.scoped(.net_common);

// TODO2: deprecate fd_nonblocking in favor of accept4 NONBLOCK

pub fn fd_nonblocking(fd: i32) !void {
    std.debug.assert(fd >= 0);

    const flags: u32 = sys.linux.fcntl(fd, linux.F.GETFL, 0) catch |err| switch (err) {
        error.Unexpected => {
            log.err("fcntl(F_GETFL) failed: unexpected error", .{});
            return err;
        },
    };

    const nonblock: u32 = @bitCast(linux.O{ .NONBLOCK = true });
    _ = sys.linux.fcntl(fd, linux.F.SETFL, flags | nonblock) catch |err| switch (err) {
        error.Unexpected => {
            log.err("fcntl(F_SETFL) failed: unexpected error", .{});
            return err;
        },
    };
    log.debug("set fd to nonblocking: fd={d} flags=(...|O.NONBLOCK)", .{fd});
}
