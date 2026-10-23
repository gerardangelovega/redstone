const std = @import("std");
const assert = @import("assert");

const Node = @import("Node.zig");

const Allocator = std.mem.Allocator;

const Table = @This();

slots: []?*Node,
mask: u32,
size: u32,

pub fn init(self: *Table, allocator: Allocator, size: u32) !void {
    self.slots = try allocator.alloc(?*Node, size);
    @memset(self.slots, null);

    self.mask = size - 1;

    self.size = 0;
}

pub fn deinit(self: *Table, allocator: Allocator) void {
    allocator.free(self.slots);
    self.slots = &.{};
}

pub fn insert(self: *Table, node: *Node) void {
    const index: usize = @intCast(node.hash & self.mask);
    node.next = self.slots[index];

    self.slots[index] = node;
    self.size = self.size + 1;
}

pub fn lookup(self: *Table, lookup_node: *Node, eq: *const fn (*Node, *Node) bool) ?*?*Node {
    if (self.slots.len == 0) return null;

    const index: usize = @intCast(lookup_node.hash & self.mask);

    var parent: *?*Node = &self.slots[index];
    var current: ?*Node = parent.*;

    while (current != null) {
        if (current.?.hash == lookup_node.hash and eq(current.?, lookup_node)) return parent;

        parent = &current.?.next;
        current = parent.*;
    }

    return null;
}

pub fn detach(self: *Table, parent: *?*Node) ?*Node {
    const node = parent.* orelse return null;

    parent.* = node.next;
    self.size = self.size - 1;

    return node;
}
