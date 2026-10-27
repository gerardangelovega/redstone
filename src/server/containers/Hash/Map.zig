const std = @import("std");

const Allocator = std.mem.Allocator;

const Table = @import("Table.zig");
const Node = @import("Node.zig");

const Map = @This();

old: Table,
new: Table,
migration_index: usize,

const load_factor_max = 1;
const rehashing_work_max = 128;

pub fn init(self: *Map, allocator: Allocator, size: u32) !void {
    self.* = .{
        .old = undefined,
        .new = undefined,
        .migration_index = 0,
    };

    self.old = .empty;
    try self.new.init(allocator, size);
    self.migration_index = 0;
}

pub fn deinit(self: *Map, allocator: Allocator) void {
    self.old.deinit(allocator);
    self.new.deinit(allocator);
}

pub fn insert(self: *Map, allocator: Allocator, node: *Node) !void {
    self.new.insert(node);
    if (self.old.slots.len == 0) {
        const threshold: usize = (self.new.mask + 1) * load_factor_max;
        if (self.new.size >= threshold) try self.resize(allocator);
    }
    self.migrate(allocator);
}

pub fn lookup(
    self: *Map,
    allocator: Allocator,
    lookup_node: *Node,
    eq: *const fn (*Node, *Node) bool,
) ?*Node {
    self.migrate(allocator);
    var parent: ?*?*Node = self.new.lookup(lookup_node, eq);
    parent = parent orelse self.old.lookup(lookup_node, eq);

    if (parent) |n| return n.* else return null;
}

pub fn detach(
    self: *Map,
    allocator: Allocator,
    lookup_node: *Node,
    eq: *const fn (*Node, *Node) bool,
) ?*Node {
    self.migrate(allocator);
    if (self.new.lookup(lookup_node, eq)) |parent| return self.new.detach(parent);
    if (self.old.lookup(lookup_node, eq)) |parent| return self.old.detach(parent);
    return null;
}

fn resize(self: *Map, allocator: Allocator) !void {
    self.old = self.new;

    self.new = undefined;
    try self.new.init(allocator, (self.old.mask + 1) * 2);

    self.migration_index = 0;
}

fn migrate(self: *Map, allocator: Allocator) void {
    var rehashing_work_count: u32 = 0;
    while (rehashing_work_count < rehashing_work_max and self.old.size > 0) {
        const parent: *?*Node = &self.old.slots[self.migration_index];
        if (parent.* == null) {
            self.migration_index = self.migration_index + 1;
            continue;
        }
        self.new.insert(self.old.detach(parent).?);
        rehashing_work_count = rehashing_work_count + 1;
    }
    if (self.old.size == 0 and self.old.slots.len > 0) {
        self.old.deinit(allocator);
        self.old = .empty;
    }
}

test "init hashmap" {
    var hashmap: Map = undefined;
    try hashmap.init(std.testing.allocator, 4);
    defer hashmap.deinit(std.testing.allocator);

    try std.testing.expect(hashmap.old.slots.len == 0);
    try std.testing.expect(hashmap.new.slots.len == 4);
    try std.testing.expect(hashmap.migration_index == 0);
}

test "insert elements" {
    var hashmap: Map = undefined;
    try hashmap.init(std.testing.allocator, 4);
    defer hashmap.deinit(std.testing.allocator);

    try std.testing.expect(hashmap.new.mask + 1 == 4);
    try std.testing.expect(hashmap.new.size == 0);

    var node1: Node = undefined;
    node1.init("key1");

    var node2: Node = undefined;
    node2.init("key2");

    var node3: Node = undefined;
    node3.init("key3");

    var node4: Node = undefined;
    node4.init("key4");

    var node5: Node = undefined;
    node5.init("key5");

    var node6: Node = undefined;
    node6.init("key6");

    try hashmap.insert(std.testing.allocator, &node1);
    try hashmap.insert(std.testing.allocator, &node2);
    try hashmap.insert(std.testing.allocator, &node3);
    try hashmap.insert(std.testing.allocator, &node4);
    try hashmap.insert(std.testing.allocator, &node5);
    try hashmap.insert(std.testing.allocator, &node6);

    try std.testing.expect(hashmap.new.mask + 1 == 8);
    try std.testing.expect(hashmap.new.size == 6);
}

fn test_eq(node_a: *Node, node_b: *Node) bool {
    return node_a.hash == node_b.hash;
}

test "lookup elements" {
    var hashmap: Map = undefined;
    try hashmap.init(std.testing.allocator, 4);
    defer hashmap.deinit(std.testing.allocator);

    try std.testing.expect(hashmap.new.mask + 1 == 4);

    var node1: Node = undefined;
    node1.init("key1");

    var node2: Node = undefined;
    node2.init("key2");

    var node3: Node = undefined;
    node3.init("key3");

    var node4: Node = undefined;
    node4.init("key4");

    var node5: Node = undefined;
    node5.init("key5");

    var node6: Node = undefined;
    node6.init("key6");

    // TEST: lookup after every insertion
    try hashmap.insert(std.testing.allocator, &node1);
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node1, test_eq).?.hash == node1.hash,
    );

    try hashmap.insert(std.testing.allocator, &node2);
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node2, test_eq).?.hash == node2.hash,
    );

    try hashmap.insert(std.testing.allocator, &node3);
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node3, test_eq).?.hash == node3.hash,
    );

    try hashmap.insert(std.testing.allocator, &node4);
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node4, test_eq).?.hash == node4.hash,
    );

    try hashmap.insert(std.testing.allocator, &node5);
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node5, test_eq).?.hash == node5.hash,
    );

    try hashmap.insert(std.testing.allocator, &node6);
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node6, test_eq).?.hash == node6.hash,
    );

    // TEST: lookup after all insertions
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node1, test_eq).?.hash == node1.hash,
    );
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node2, test_eq).?.hash == node2.hash,
    );
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node3, test_eq).?.hash == node3.hash,
    );
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node4, test_eq).?.hash == node4.hash,
    );
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node5, test_eq).?.hash == node5.hash,
    );
    try std.testing.expect(
        hashmap.lookup(std.testing.allocator, &node6, test_eq).?.hash == node6.hash,
    );
}

test "detach elements" {
    var hashmap: Map = undefined;
    try hashmap.init(std.testing.allocator, 4);
    defer hashmap.deinit(std.testing.allocator);

    try std.testing.expect(hashmap.new.mask + 1 == 4);

    var node1: Node = undefined;
    node1.init("key1");

    var node2: Node = undefined;
    node2.init("key2");

    var node3: Node = undefined;
    node3.init("key3");

    var node4: Node = undefined;
    node4.init("key4");

    var node5: Node = undefined;
    node5.init("key5");

    var node6: Node = undefined;
    node6.init("key6");

    try hashmap.insert(std.testing.allocator, &node1);
    try hashmap.insert(std.testing.allocator, &node2);
    try hashmap.insert(std.testing.allocator, &node3);
    try hashmap.insert(std.testing.allocator, &node4);
    try hashmap.insert(std.testing.allocator, &node5);
    try hashmap.insert(std.testing.allocator, &node6);

    _ = hashmap.detach(std.testing.allocator, &node1, test_eq);
    _ = hashmap.detach(std.testing.allocator, &node3, test_eq);
    _ = hashmap.detach(std.testing.allocator, &node5, test_eq);

    try std.testing.expect(hashmap.lookup(std.testing.allocator, &node1, test_eq) == null);
    try std.testing.expect(hashmap.lookup(std.testing.allocator, &node3, test_eq) == null);
    try std.testing.expect(hashmap.lookup(std.testing.allocator, &node5, test_eq) == null);

    try std.testing.expect(hashmap.lookup(std.testing.allocator, &node2, test_eq) != null);
    try std.testing.expect(hashmap.lookup(std.testing.allocator, &node4, test_eq) != null);
    try std.testing.expect(hashmap.lookup(std.testing.allocator, &node6, test_eq) != null);

    try std.testing.expect(hashmap.new.size == 3);
}
