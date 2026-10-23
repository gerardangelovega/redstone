const std = @import("std");

const protocol = @import("protocol");

const Store = @import("../Store.zig");
const String = protocol.registry.Command.String;
const Request = protocol.message.Request;
const Response = protocol.message.Response;

pub fn string(
    allocator: std.mem.Allocator,
    store: *Store,
    command: String,
    request_in: *const Request,
    response_out: *Response,
) !void {
    switch (command) {
        .get => {
            try get(allocator, store, request_in, response_out);
        },
        .set => {
            try set(allocator, store, request_in, response_out);
        },
    }
}

fn get(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    if (!String.arities.get(.get).contains(request_in.header.data_count)) {
        try response_out.init(allocator, .err, &.{.{ .err = "get bad arguments" }});
        return;
    }
    if (request_in.body.data[0] != .str) {
        try response_out.init(allocator, .err, &.{.{ .err = "get bad type, expected string" }});
        return;
    }

    const key = request_in.body.data[0].str;
    const value = store.data.get(request_in.body.data[0].str);
    if (value) |v| {
        std.log.debug("key: {s}, value: {s}", .{ key, v });
        try response_out.init(allocator, .ok, &.{.{ .str = v }});
    } else {
        try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    }
}

fn set(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    if (!String.arities.get(.set).contains(request_in.header.data_count)) {
        try response_out.init(allocator, .err, &.{.{ .err = "set bad arguments" }});
        return;
    }
    if (request_in.body.data[0] != .str or request_in.body.data[1] != .str) {
        try response_out.init(allocator, .err, &.{.{ .err = "set bad type, expected string" }});
        return;
    }

    const key = try allocator.dupe(u8, request_in.body.data[0].str);
    const value = try allocator.dupe(u8, request_in.body.data[1].str);
    std.log.debug("set key: {s}, value: {s}", .{ key, value });
    try store.data.put(key, value);
    std.log.debug("from data: {s}", .{store.data.get(key).?});
    try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
}
