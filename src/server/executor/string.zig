const std = @import("std");

const protocol = @import("protocol");

const containers = @import("../containers.zig");
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

    var lookup_node: containers.Hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    const result_object = containers.Object.from(result_node.?);
    const result_string = containers.Object.String.from(result_object);

    const value = result_string.string;
    // if (value) |v| {
    std.log.debug("key: {s}, value: {s}", .{ key, value });
    try response_out.init(allocator, .ok, &.{.{ .str = value }});
    // } else {
    //     try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    // }
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

    const key = request_in.body.data[0].str;
    const value = request_in.body.data[1].str;

    var object_string = try allocator.create(containers.Object.String);
    try object_string.init(allocator, key, value);

    std.log.debug("set key: {s}, value: {s}", .{ key, value });
    try store.data.insert(allocator, &object_string.object.hash_node);

    const result_node = store.data.lookup(allocator, &object_string.object.hash_node, eq);
    const result_object = containers.Object.from(result_node.?);
    const result_string = containers.Object.String.from(result_object);

    std.log.debug("from data: {s}", .{result_string.string});
    try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
}

fn eq(node_a: *containers.Hash.Node, node_b: *containers.Hash.Node) bool {
    return node_a.hash == node_b.hash;
}
