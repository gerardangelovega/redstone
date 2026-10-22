// standard library, library, and module imports
const std = @import("std");
const protocol = @import("protocol");

// files
const net = @import("net.zig");

// aliases

pub fn main(init: std.process.Init) void {
    const gpa = init.gpa;

    // SAFETY: initialized by init()
    var connection: net.Connection = undefined;
    connection.init();
    defer connection.deinit(gpa);

    connection.connect([4]u8{ 127, 0, 0, 1 }, 6767);

    // SAFETY: initialized by init()
    var request: protocol.message.Request = undefined;
    request.init(.{ .connection = .echo }, &.{
        .{ .str = "hello" },
    });

    if (!connection.send_request(gpa, &request)) return;
    if (!connection.send_request(gpa, &request)) return;
    if (!connection.send_request(gpa, &request)) return;
    if (!connection.receive_response(gpa)) return;
    if (!connection.receive_response(gpa)) return;
    if (!connection.receive_response(gpa)) return;
}
