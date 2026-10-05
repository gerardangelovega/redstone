const std = @import("std");
const linux = std.os.linux;
const shared = @import("shared");

const net = @import("net.zig");
const EventLoop = @import("EventLoop.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var event_loop: EventLoop = undefined;
    event_loop.init(gpa);
    defer event_loop.deinit(gpa);
    event_loop.run(gpa);
}
