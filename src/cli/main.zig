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
    var request_echo: protocol.message.Request = undefined;
    request_echo.init(.{ .connection = .echo }, &.{
        .{ .str = "hello" },
    });

    if (!connection.send_request(gpa, &request_echo)) return;
    if (!connection.send_request(gpa, &request_echo)) return;
    if (!connection.send_request(gpa, &request_echo)) return;
    if (!connection.receive_response(gpa)) return;
    if (!connection.receive_response(gpa)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_ping: protocol.message.Request = undefined;
    request_ping.init(.{ .connection = .ping }, &.{});

    if (!connection.send_request(gpa, &request_ping)) return;
    if (!connection.send_request(gpa, &request_ping)) return;
    if (!connection.send_request(gpa, &request_ping)) return;
    if (!connection.receive_response(gpa)) return;
    if (!connection.receive_response(gpa)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_get: protocol.message.Request = undefined;
    request_get.init(.{ .string = .get }, &.{.{ .str = "key" }});

    if (!connection.send_request(gpa, &request_get)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_set: protocol.message.Request = undefined;
    request_set.init(.{ .string = .set }, &.{ .{ .str = "key" }, .{ .str = "value" } });

    if (!connection.send_request(gpa, &request_set)) return;
    if (!connection.receive_response(gpa)) return;
}
