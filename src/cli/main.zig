// standard library, library, and module imports
const std = @import("std");
const protocol = @import("protocol");
const sys = @import("sys");

// files
const net = @import("net.zig");

// aliases
const Allocator = std.mem.Allocator;
const linux = std.os.linux;
const log = std.log;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var connection: net.Connection = undefined;
    connection.init();
    defer connection.deinit(gpa);

    connection.connect([4]u8{ 127, 0, 0, 1 }, 6767);

    if (!connection.send_request(gpa, "hello a")) return;
    if (!connection.send_request(gpa, "hello b")) return;
    if (!connection.send_request(gpa, "hello c")) return;

    if (!connection.receive_response(gpa)) return;
    if (!connection.receive_response(gpa)) return;
    if (!connection.receive_response(gpa)) return;
}
