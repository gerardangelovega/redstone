const std = @import("std");
const linux = std.os.linux;
const log = std.log.scoped(.net_epoll);

const common = @import("common.zig");

/// Wrapper around the epoll related data and Linux syscalls
const Epoll = @This();

const Op = enum(u8) { add, mod, del };
const max_events = 256;

fd: i32,
events: [max_events]linux.epoll_event,

/// Initializes the `Epoll` wrapper struct by creating an fd referring to an
/// epoll instance with the epoll_create1() Linux syscall
pub fn init(self: *Epoll) void {
    const rv: usize = linux.epoll_create1(linux.EPOLL.CLOEXEC);
    const fd: i32 = switch (linux.errno(rv)) {
        .SUCCESS => @intCast(rv),
        .MFILE => {
            log.err("epoll_create1() failed: MFILE, process fd limit reached", .{});
            std.process.exit(1);
        },
        .NFILE => {
            log.err("epoll_create1() failed: NFILE, system fd limit reached", .{});
            std.process.exit(1);
        },
        .NOMEM => {
            log.err("epoll_create1() failed: NOMEM, insufficient memory", .{});
            std.process.exit(1);
        },
        else => |errno| {
            log.err("epoll_create1() failed: errno={s}", .{@tagName(errno)});
            @panic("epoll_create1() failed");
        },
    };
    log.debug("epoll instance created: fd={d}", .{fd});

    self.* = .{ .fd = fd, .events = undefined };
    log.info("epoll instance initialized", .{});
}

/// Deinitializes the `Epoll` wrapper struct by closing the fd referring to an
/// epoll instance and setting the `Epoll` fd to -1
pub fn deinit(self: *Epoll) void {
    std.debug.assert(self.fd >= 0);

    common.fd_close(self.fd);

    self.fd = -1;
    log.info("epoll instance deinitialized", .{});
}

/// Adds an fd along with events to track into the interest list of the epoll
/// instance.
///
/// Returns `true` when `fd` and `events` were successfully registered into
/// the interest list. Returns `false` on an ENOMEM/ENOSPC error.
pub fn add(self: *const Epoll, fd: i32, events: u32) bool {
    std.debug.assert(fd >= 0);

    var event: linux.epoll_event = .{ .events = events, .data = .{ .fd = fd } };
    return self.ctl(.add, fd, &event);
}

/// Modifies an existing entry's data and event states in the epoll instance
/// interest list
pub fn modify(self: *const Epoll, fd: i32, events: u32) void {
    std.debug.assert(fd >= 0);

    // If `Epoll`.`ctl()` does not panic, it always returns true for `CTL_MOD`.
    var event: linux.epoll_event = .{ .events = events, .data = .{ .fd = fd } };
    const ok = self.ctl(.mod, fd, &event);
    std.debug.assert(ok);
}

/// Deletes an existing entry in the epoll instance interest list.
pub fn delete(self: *const Epoll, fd: i32) void {
    std.debug.assert(fd >= 0);

    // If `Epoll`.`ctl()` does not panic, it always returns true for `CTL_DEL`.
    const ok = self.ctl(.del, fd, null);
    std.debug.assert(ok);
}

/// Writes fds in the epoll instance ready list to `Epoll`.`events`
/// *([]`epoll_event`)* and returns the following:
/// - A slice of length `n` where `n` is the number of ready fds
/// - A slice of length `0` if `epoll_wait` was interrupted
///
/// *(the returned slice is only valid until the next `Epoll`.`wait()`)*
pub fn wait(self: *Epoll, timeout_ms: i32) []const linux.epoll_event {
    const rv: usize = linux.epoll_wait(
        self.fd,
        &self.events,
        max_events,
        timeout_ms,
    );
    switch (linux.errno(rv)) {
        .SUCCESS => {
            return self.events[0..rv];
        },
        .INTR => {
            return self.events[0..0];
        },
        else => |errno| {
            log.err(
                "epoll_wait() failed: epfd={d} maxevents={d} errno={s}",
                .{ self.fd, max_events, @tagName(errno) },
            );
            @panic("epoll_wait() failed");
        },
    }
}

/// Abstracts `epoll_ctl` `CTL_ADD`, `CTL_MOD`, and `CTL_DEL` operations into a
/// single interface *(internal use only)*.
///
/// Returns `true` if the operation was a success, `false` if the operation
/// failed but is still recoverable, and `@panic` if the program reaches an
/// invalid and unrecoverable state.
fn ctl(self: *const Epoll, op: Op, fd: i32, event: ?*linux.epoll_event) bool {
    const epoll_op: u32 = switch (op) {
        .add => linux.EPOLL.CTL_ADD,
        .mod => linux.EPOLL.CTL_MOD,
        .del => linux.EPOLL.CTL_DEL,
    };
    const rv = linux.epoll_ctl(self.fd, epoll_op, fd, event);
    switch (linux.errno(rv)) {
        .SUCCESS => {
            return true;
        },
        .NOMEM => switch (op) {
            .add => {
                log.warn("epoll_ctl(add) failed: NOMEM, insufficient memory", .{});
                return false;
            },
            else => {
                log.err(
                    "epoll_ctl({s}) failed: NOMEM, insufficient memory",
                    .{@tagName(op)},
                );
                @panic("epoll_ctl() failed");
            },
        },
        .NOSPC => switch (op) {
            .add => {
                log.warn("epoll_ctl(add) failed: NOSPC, watched limit reached", .{});
                return false;
            },
            else => {
                log.err(
                    "epoll_ctl({s}) failed: NOSPC, watched limit reached",
                    .{@tagName(op)},
                );
                @panic("epoll_ctl() failed");
            },
        },
        else => |errno| {
            log.err(
                "epoll_ctl() failed: op={s} fd={d} epfd={d} errno={s}",
                .{ @tagName(op), fd, self.fd, @tagName(errno) },
            );
            @panic("epoll_ctl() failed");
        },
    }
}
