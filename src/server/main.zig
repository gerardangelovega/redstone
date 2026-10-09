// standard library, library, and module imports
const std = @import("std");
const sys = @import("sys");

// file imports
const EventLoop = @import("EventLoop.zig");
const net = @import("net.zig");

// aliases
const linux = std.os.linux;
const log = std.log;

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var event_loop: EventLoop = undefined;
    event_loop.init(gpa);
    event_loop.run(gpa);
    event_loop.deinit(gpa);
}
