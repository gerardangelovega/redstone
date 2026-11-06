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
    var request_set: protocol.message.Request = undefined;
    request_set.init(gpa, .{ .string = .set }, &.{
        .{ .str = "key" },
        .{ .str = "value" },
    }) catch return;
    defer request_set.deinit(gpa);

    if (!connection.send_request(gpa, &request_set)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_get: protocol.message.Request = undefined;
    request_get.init(gpa, .{ .string = .get }, &.{.{ .str = "key" }}) catch return;
    defer request_get.deinit(gpa);

    if (!connection.send_request(gpa, &request_get)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_push_front_a: protocol.message.Request = undefined;
    request_push_front_a.init(
        gpa,
        .{ .list = .push_front },
        &.{ .{ .str = "list_key" }, .{ .str = "list_value_a" } },
    ) catch return;
    defer request_push_front_a.deinit(gpa);

    if (!connection.send_request(gpa, &request_push_front_a)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_push_front_b: protocol.message.Request = undefined;
    request_push_front_b.init(
        gpa,
        .{ .list = .push_front },
        &.{ .{ .str = "list_key" }, .{ .str = "list_value_b" } },
    ) catch return;
    defer request_push_front_b.deinit(gpa);

    if (!connection.send_request(gpa, &request_push_front_b)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_push_back_c: protocol.message.Request = undefined;
    request_push_back_c.init(
        gpa,
        .{ .list = .push_back },
        &.{ .{ .str = "list_key" }, .{ .str = "list_value_c" } },
    ) catch return;
    defer request_push_back_c.deinit(gpa);

    if (!connection.send_request(gpa, &request_push_back_c)) return;
    if (!connection.receive_response(gpa)) return;

    // SAFETY: initialized by init()
    var request_push_back_d: protocol.message.Request = undefined;
    request_push_back_d.init(
        gpa,
        .{ .list = .push_back },
        &.{ .{ .str = "list_key" }, .{ .str = "list_value_d" } },
    ) catch return;
    defer request_push_back_d.deinit(gpa);

    if (!connection.send_request(gpa, &request_push_back_d)) return;
    if (!connection.receive_response(gpa)) return;

    var request_front: protocol.message.Request = undefined;
    request_front.init(
        gpa,
        .{ .list = .front },
        &.{.{ .str = "list_key" }},
    ) catch return;
    defer request_front.deinit(gpa);

    if (!connection.send_request(gpa, &request_front)) return;
    if (!connection.receive_response(gpa)) return;

    var request_back: protocol.message.Request = undefined;
    request_back.init(
        gpa,
        .{ .list = .back },
        &.{.{ .str = "list_key" }},
    ) catch return;
    defer request_back.deinit(gpa);

    if (!connection.send_request(gpa, &request_back)) return;
    if (!connection.receive_response(gpa)) return;

    var request_pop_front: protocol.message.Request = undefined;
    request_pop_front.init(
        gpa,
        .{ .list = .pop_front },
        &.{.{ .str = "list_key" }},
    ) catch return;
    defer request_pop_front.deinit(gpa);

    if (!connection.send_request(gpa, &request_pop_front)) return;
    if (!connection.receive_response(gpa)) return;

    var request_pop_back: protocol.message.Request = undefined;
    request_pop_back.init(
        gpa,
        .{ .list = .pop_back },
        &.{.{ .str = "list_key" }},
    ) catch return;
    defer request_pop_back.deinit(gpa);

    if (!connection.send_request(gpa, &request_pop_back)) return;
    if (!connection.receive_response(gpa)) return;

    var request_length: protocol.message.Request = undefined;
    request_length.init(
        gpa,
        .{ .list = .length },
        &.{.{ .str = "list_key" }},
    ) catch return;
    defer request_length.deinit(gpa);

    if (!connection.send_request(gpa, &request_length)) return;
    if (!connection.receive_response(gpa)) return;

    var request_insert_before: protocol.message.Request = undefined;
    request_insert_before.init(
        gpa,
        .{ .list = .insert_before },
        &.{ .{ .str = "list_key" }, .{ .int = 1 }, .{ .str = "list_value_b" } },
    ) catch return;
    defer request_insert_before.deinit(gpa);

    if (!connection.send_request(gpa, &request_insert_before)) return;
    if (!connection.receive_response(gpa)) return;

    var request_insert_after: protocol.message.Request = undefined;
    request_insert_after.init(
        gpa,
        .{ .list = .insert_after },
        &.{ .{ .str = "list_key" }, .{ .int = 2 }, .{ .str = "list_value_d" } },
    ) catch return;
    defer request_insert_after.deinit(gpa);

    if (!connection.send_request(gpa, &request_insert_after)) return;
    if (!connection.receive_response(gpa)) return;

    var request_update_0: protocol.message.Request = undefined;
    request_update_0.init(
        gpa,
        .{ .list = .update },
        &.{ .{ .str = "list_key" }, .{ .int = 0 }, .{ .str = "list_value_aa" } },
    ) catch return;
    defer request_update_0.deinit(gpa);

    if (!connection.send_request(gpa, &request_update_0)) return;
    if (!connection.receive_response(gpa)) return;

    var request_index_0: protocol.message.Request = undefined;
    request_index_0.init(
        gpa,
        .{ .list = .index },
        &.{ .{ .str = "list_key" }, .{ .int = 0 } },
    ) catch return;
    defer request_index_0.deinit(gpa);

    if (!connection.send_request(gpa, &request_index_0)) return;
    if (!connection.receive_response(gpa)) return;

    var request_index_1: protocol.message.Request = undefined;
    request_index_1.init(
        gpa,
        .{ .list = .index },
        &.{ .{ .str = "list_key" }, .{ .int = 1 } },
    ) catch return;
    defer request_index_1.deinit(gpa);

    if (!connection.send_request(gpa, &request_index_1)) return;
    if (!connection.receive_response(gpa)) return;

    var request_index_2: protocol.message.Request = undefined;
    request_index_2.init(
        gpa,
        .{ .list = .index },
        &.{ .{ .str = "list_key" }, .{ .int = 2 } },
    ) catch return;
    defer request_index_2.deinit(gpa);

    if (!connection.send_request(gpa, &request_index_2)) return;
    if (!connection.receive_response(gpa)) return;

    var request_index_3: protocol.message.Request = undefined;
    request_index_3.init(
        gpa,
        .{ .list = .index },
        &.{ .{ .str = "list_key" }, .{ .int = 3 } },
    ) catch return;
    defer request_index_3.deinit(gpa);

    if (!connection.send_request(gpa, &request_index_3)) return;
    if (!connection.receive_response(gpa)) return;

    var request_remove_2: protocol.message.Request = undefined;
    request_remove_2.init(
        gpa,
        .{ .list = .remove },
        &.{ .{ .str = "list_key" }, .{ .int = 2 } },
    ) catch return;
    defer request_remove_2.deinit(gpa);

    if (!connection.send_request(gpa, &request_remove_2)) return;
    if (!connection.receive_response(gpa)) return;
}
