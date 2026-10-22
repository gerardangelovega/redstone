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
    var request_invalid_1: protocol.message.Request = undefined;
    request_invalid_1.init(.{ .connection = .invalid }, &.{});

    if (!connection.send_request(gpa, &request_invalid_1)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_echo_1: protocol.message.Request = undefined;
    request_echo_1.init(.{ .connection = .echo }, &.{
        .{ .str = "hello" },
    });

    if (!connection.send_request(gpa, &request_echo_1)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_echo_2: protocol.message.Request = undefined;
    request_echo_2.init(.{ .connection = .echo }, &.{
        .{ .str = "hello" },
        .{ .str = "world" },
    });

    if (!connection.send_request(gpa, &request_echo_2)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_echo_3: protocol.message.Request = undefined;
    request_echo_3.init(.{ .connection = .echo }, &.{
        .{ .dbl = 3.14 },
    });

    if (!connection.send_request(gpa, &request_echo_3)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_ping_1: protocol.message.Request = undefined;
    request_ping_1.init(.{ .connection = .ping }, &.{});

    if (!connection.send_request(gpa, &request_ping_1)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_ping_2: protocol.message.Request = undefined;
    request_ping_2.init(.{ .connection = .ping }, &.{.{ .str = "ping" }});

    if (!connection.send_request(gpa, &request_ping_2)) return;
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
