// standard library, library, and module imports
const std = @import("std");

// file imports
const EventLoop = @import("EventLoop.zig");

const protocol = @import("protocol");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main(init: std.process.Init) void {
    const gpa = init.gpa;

    const get: protocol.Command = .{ .keyspace = .get };
    std.debug.print("keyspace command is: {s}\n", .{@tagName(get.keyspace)});
    std.debug.print("keyspace command opcode is: {d}\n", .{get.encode()});

    const del = protocol.Command.decode(401);
    std.debug.print("keyspace command is: {s}\n", .{@tagName(del.keyspace)});
    std.debug.print("keyspace command opcode is: {d}\n", .{del.encode()});

    // SAFETY: initialized in-place with event_loop.init()
    var event_loop: EventLoop = undefined;
    event_loop.init(gpa);
    event_loop.run(gpa);
    event_loop.deinit(gpa);
}
