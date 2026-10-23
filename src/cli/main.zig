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
    request_invalid_1.init(gpa, .{ .connection = .invalid }, &.{}) catch return;
    defer request_invalid_1.deinit(gpa);

    if (!connection.send_request(gpa, &request_invalid_1)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_echo_1: protocol.message.Request = undefined;
    request_echo_1.init(gpa, .{ .connection = .echo }, &.{
        .{ .str = "hello" },
    }) catch return;
    defer request_echo_1.deinit(gpa);

    if (!connection.send_request(gpa, &request_echo_1)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_echo_2: protocol.message.Request = undefined;
    request_echo_2.init(gpa, .{ .connection = .echo }, &.{
        .{ .str = "hello" },
        .{ .str = "world" },
    }) catch return;
    defer request_echo_2.deinit(gpa);

    if (!connection.send_request(gpa, &request_echo_2)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_echo_3: protocol.message.Request = undefined;
    request_echo_3.init(gpa, .{ .connection = .echo }, &.{
        .{ .dbl = 3.14 },
    }) catch return;
    defer request_echo_3.deinit(gpa);

    if (!connection.send_request(gpa, &request_echo_3)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_ping_1: protocol.message.Request = undefined;
    request_ping_1.init(gpa, .{ .connection = .ping }, &.{}) catch return;
    defer request_ping_1.deinit(gpa);

    if (!connection.send_request(gpa, &request_ping_1)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_ping_2: protocol.message.Request = undefined;
    request_ping_2.init(gpa, .{ .connection = .ping }, &.{.{ .str = "ping" }}) catch return;
    defer request_ping_2.deinit(gpa);

    if (!connection.send_request(gpa, &request_ping_2)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_get: protocol.message.Request = undefined;
    request_get.init(gpa, .{ .string = .get }, &.{.{ .str = "key" }}) catch return;
    defer request_get.deinit(gpa);

    if (!connection.send_request(gpa, &request_get)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_set: protocol.message.Request = undefined;
    request_set.init(gpa, .{ .string = .set }, &.{
        .{ .str = "key" },
        .{ .str = "value" },
    }) catch return;
    defer request_set.deinit(gpa);

    if (!connection.send_request(gpa, &request_set)) return;
    if (!connection.receive_response(gpa)) return;
}
