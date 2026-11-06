const std = @import("std");

const protocol = @import("protocol");

const containers = @import("../containers.zig");
const Store = @import("../Store.zig");
const List = protocol.registry.Command.List;
const Request = protocol.message.Request;
const Response = protocol.message.Response;

// TODO: figure out if there are potential leaks and fix them
// TODO: handle deletion of nodes in pop_front
// TODO: handle deletion of nodes in pop_back
// TODO: handle deletion of nodes in remove

pub fn list(
    allocator: std.mem.Allocator,
    store: *Store,
    command: List,
    request_in: *const Request,
    response_out: *Response,
) !void {
    switch (command) {
        .push_front => {
            try push_front(allocator, store, request_in, response_out);
        },
        .push_back => {
            try push_back(allocator, store, request_in, response_out);
        },
        .pop_front => {
            try pop_front(allocator, store, request_in, response_out);
        },
        .pop_back => {
            try pop_back(allocator, store, request_in, response_out);
        },
        .front => {
            try front(allocator, store, request_in, response_out);
        },
        .back => {
            try back(allocator, store, request_in, response_out);
        },
        .insert_before => {
            try insert_before(allocator, store, request_in, response_out);
        },
        .insert_after => {
            try insert_after(allocator, store, request_in, response_out);
        },
        .index => {
            try index(allocator, store, request_in, response_out);
        },
        .update => {
            try update(allocator, store, request_in, response_out);
        },
        .remove => {
            try remove(allocator, store, request_in, response_out);
        },
        .length => {
            try length(allocator, store, request_in, response_out);
        },
    }
}

fn push_front(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;
    const value = request_in.body.data[1].str;

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    var result_object: *containers.Object = undefined;
    var result_list: *containers.Object.List = undefined;

    if (result_node) |node| {
        result_object = containers.Object.from(node);
        result_list = containers.Object.List.from(result_object);
    } else {
        result_list = try allocator.create(containers.Object.List);
        try result_list.init(allocator, key);
        result_object = &result_list.object;
        try store.data.insert(allocator, &result_object.hash_node);
    }

    const list_node: *containers.list.Node = try allocator.create(containers.list.Node);
    try list_node.init(allocator, value);

    _ = result_list.list.push_front(list_node);
    print_list(&result_list.list);

    try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
}

fn push_back(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;
    const value = request_in.body.data[1].str;

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    var result_object: *containers.Object = undefined;
    var result_list: *containers.Object.List = undefined;

    if (result_node) |node| {
        result_object = containers.Object.from(node);
        result_list = containers.Object.List.from(result_object);
    } else {
        try result_list.init(allocator, key);
        result_object = &result_list.object;
        try store.data.insert(allocator, &result_object.hash_node);
    }

    const list_node: *containers.list.Node = try allocator.create(containers.list.Node);
    try list_node.init(allocator, value);

    _ = result_list.list.push_back(list_node);
    print_list(&result_list.list);

    try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
}

fn pop_front(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    if (result_node == null) {
        try response_out.init(allocator, .err, &.{.{ .err = "key not found" }});
        return;
    }

    const result_object: *containers.Object = .from(result_node.?);
    const result_list: *containers.Object.List = .from(result_object);
    const list_node: ?*containers.list.Node = result_list.list.pop_front();

    if (list_node != null) {
        try response_out.init(allocator, .ok, &.{.{ .str = list_node.?.value }});
    } else {
        try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    }

    print_list(&result_list.list);
}

fn pop_back(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    if (result_node == null) {
        try response_out.init(allocator, .err, &.{.{ .err = "key not found" }});
        return;
    }

    const result_object: *containers.Object = .from(result_node.?);
    const result_list: *containers.Object.List = .from(result_object);
    const list_node: ?*containers.list.Node = result_list.list.pop_back();

    if (list_node != null) {
        try response_out.init(allocator, .ok, &.{.{ .str = list_node.?.value }});
    } else {
        try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    }

    print_list(&result_list.list);
}

fn front(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    if (result_node == null) {
        try response_out.init(allocator, .err, &.{.{ .err = "key not found" }});
        return;
    }

    const result_object: *containers.Object = .from(result_node.?);
    const result_list: *containers.Object.List = .from(result_object);
    const list_node: ?*containers.list.Node = result_list.list.front();

    if (list_node != null) {
        try response_out.init(allocator, .ok, &.{.{ .str = list_node.?.value }});
    } else {
        try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    }
}

fn back(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    if (result_node == null) {
        try response_out.init(allocator, .err, &.{.{ .err = "key not found" }});
        return;
    }

    const result_object: *containers.Object = .from(result_node.?);
    const result_list: *containers.Object.List = .from(result_object);
    const list_node: ?*containers.list.Node = result_list.list.back();

    if (list_node != null) {
        try response_out.init(allocator, .ok, &.{.{ .str = list_node.?.value }});
    } else {
        try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    }
}

fn insert_before(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;
    const idx: u32 = @intCast(request_in.body.data[1].int);
    const value = request_in.body.data[2].str;

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    if (result_node == null) {
        try response_out.init(allocator, .err, &.{.{ .err = "key not found" }});
        return;
    }
    const result_object: *containers.Object = .from(result_node.?);
    const result_list: *containers.Object.List = .from(result_object);

    const list_node: *containers.list.Node = try allocator.create(containers.list.Node);
    try list_node.init(allocator, value);

    const insert_result = result_list.list.insert_before(idx, list_node);
    if (insert_result) {
        try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    } else {
        try response_out.init(allocator, .err, &.{.{ .err = "insert before failed" }});
    }
    print_list(&result_list.list);
}

fn insert_after(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;
    const idx: u32 = @intCast(request_in.body.data[1].int);
    const value = request_in.body.data[2].str;

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    if (result_node == null) {
        try response_out.init(allocator, .err, &.{.{ .err = "key not found" }});
        return;
    }
    const result_object: *containers.Object = .from(result_node.?);
    const result_list: *containers.Object.List = .from(result_object);

    const list_node: *containers.list.Node = try allocator.create(containers.list.Node);
    try list_node.init(allocator, value);

    const insert_result = result_list.list.insert_after(idx, list_node);
    if (insert_result) {
        try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    } else {
        try response_out.init(allocator, .err, &.{.{ .err = "insert after failed" }});
    }
    print_list(&result_list.list);
}

fn index(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;
    const idx: u32 = @intCast(request_in.body.data[1].int);

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    if (result_node == null) {
        try response_out.init(allocator, .err, &.{.{ .err = "key not found" }});
        return;
    }

    const result_object: *containers.Object = .from(result_node.?);
    const result_list: *containers.Object.List = .from(result_object);
    const list_node: ?*containers.list.Node = result_list.list.lookup(idx);

    if (list_node != null) {
        try response_out.init(allocator, .ok, &.{.{ .str = list_node.?.value }});
    } else {
        try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    }
}

fn update(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;
    const idx: u32 = @intCast(request_in.body.data[1].int);
    const value = request_in.body.data[2].str;

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    if (result_node == null) {
        try response_out.init(allocator, .err, &.{.{ .err = "key not found" }});
        return;
    }
    const result_object: *containers.Object = .from(result_node.?);
    const result_list: *containers.Object.List = .from(result_object);
    const update_result: bool = try result_list.list.update(allocator, idx, value);

    if (update_result) {
        try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    } else {
        try response_out.init(allocator, .err, &.{.{ .err = "update failed" }});
    }
    print_list(&result_list.list);
}

fn remove(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;
    const idx: u32 = @intCast(request_in.body.data[1].int);

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    if (result_node == null) {
        try response_out.init(allocator, .err, &.{.{ .err = "key not found" }});
        return;
    }
    const result_object: *containers.Object = .from(result_node.?);
    const result_list: *containers.Object.List = .from(result_object);
    const removed_node: ?*containers.list.Node = result_list.list.remove(idx);

    if (removed_node != null) {
        try response_out.init(allocator, .ok, &.{.{ .str = removed_node.?.value }});
    } else {
        try response_out.init(allocator, .ok, &.{.{ .nil = {} }});
    }
    print_list(&result_list.list);
}

fn length(
    allocator: std.mem.Allocator,
    store: *Store,
    request_in: *const Request,
    response_out: *Response,
) !void {
    const key = request_in.body.data[0].str;

    var lookup_node: containers.hash.Node = undefined;
    lookup_node.init(key);

    const result_node = store.data.lookup(allocator, &lookup_node, eq);
    if (result_node == null) {
        try response_out.init(allocator, .err, &.{.{ .err = "key not found" }});
        return;
    }

    const result_object: *containers.Object = .from(result_node.?);
    const result_list: *containers.Object.List = .from(result_object);

    try response_out.init(allocator, .ok, &.{.{ .int = result_list.list.size }});
}

fn eq(node_a: *containers.hash.Node, node_b: *containers.hash.Node) bool {
    return node_a.hash == node_b.hash;
}

fn print_list(lst: *containers.list.List) void {
    var curr: ?*containers.list.Node = lst.head;

    while (curr) |c| {
        if (c != lst.head and c != lst.tail) {
            std.debug.print("{s} ", .{c.value});
        }
        std.debug.print("\n", .{});
        curr = c.next;
    }
}
