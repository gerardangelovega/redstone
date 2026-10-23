const std = @import("std");

const Table = @import("Table.zig");
const Node = @import("Node.zig");

test "init table" {
    std.debug.print("Test #1: table init\n", .{});

    var table: Table = undefined;
    try table.init(std.testing.allocator, 1024);
    defer table.deinit(std.testing.allocator);

    try std.testing.expect(table.slots.len == 1024);
    try std.testing.expect(table.mask == 1024 - 1);
    try std.testing.expect(table.size == 0);

    std.debug.print("Test #1 Passed\n\n", .{});
}

fn eq(node_a: *Node, node_b: *Node) bool {
    return node_a.hash == node_b.hash;
}

test "insert and lookup" {
    std.debug.print("Test #2: hash table insert and lookup\n", .{});

    var table: Table = undefined;
    try table.init(std.testing.allocator, 1024);
    defer table.deinit(std.testing.allocator);

    var node_a: Node = undefined;
    var node_b: Node = undefined;
    node_a.init("key1");
    node_b.init("key2");

    table.insert(&node_a);
    try std.testing.expect(table.size == 1);

    table.insert(&node_b);
    try std.testing.expect(table.size == 2);

    var lookup_node_a: Node = undefined;
    var lookup_node_b: Node = undefined;
    lookup_node_a.init("key1");
    lookup_node_b.init("key2");

    const result_a = table.lookup(&lookup_node_a, eq);
    std.debug.print(
        "result_a hash: {d}, node_a hash: {d}\n",
        .{ result_a.?.*.?.hash, node_a.hash },
    );
    try std.testing.expect(result_a.?.*.?.hash == node_a.hash);

    const result_b = table.lookup(&lookup_node_b, eq);
    std.debug.print(
        "result_b hash: {d}, node_b hash: {d}\n",
        .{ result_b.?.*.?.hash, node_b.hash },
    );
    try std.testing.expect(result_b.?.*.?.hash == node_b.hash);

    std.debug.print("Test #2 Passed\n\n", .{});
}

test "insert, lookup, and delete" {
    std.debug.print("Test #3: hash table insert, lookup, and delete\n", .{});

    var table: Table = undefined;
    try table.init(std.testing.allocator, 1024);
    defer table.deinit(std.testing.allocator);

    var node_a: Node = undefined;
    var node_b: Node = undefined;
    node_a.init("key1");
    node_b.init("key2");

    table.insert(&node_a);
    table.insert(&node_b);
    try std.testing.expect(table.size == 2);
    std.debug.print("table size after insert: {d}\n", .{table.size});

    var lookup_node_a: Node = undefined;
    var lookup_node_b: Node = undefined;
    lookup_node_a.init("key1");
    lookup_node_b.init("key2");

    const to_detach_b = table.lookup(&lookup_node_b, eq);
    const detached_b = table.detach(to_detach_b.?);
    try std.testing.expect(table.size == 1);
    try std.testing.expect(lookup_node_b.hash == detached_b.?.hash);
    std.debug.print("table size after detach: {d}\n", .{table.size});

    const result_b = table.lookup(&lookup_node_b, eq);
    try std.testing.expect(result_b == null);
    std.debug.print("result after looking up node_b: {any}\n", .{result_b});

    std.debug.print("Test #3 Passed\n\n", .{});
}
