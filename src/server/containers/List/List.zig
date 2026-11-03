const std = @import("std");
const assert = @import("assert");

const Node = @import("Node.zig");
const List = @This();

head: *Node,
tail: *Node,
size: u32,

pub fn init(self: *List, allocator: std.mem.Allocator) !void {
    self.* = .{
        .head = try allocator.create(Node),
        .tail = try allocator.create(Node),
        .size = 0,
    };
    try self.head.init(allocator, "");
    try self.tail.init(allocator, "");

    self.head.next = self.tail;
    self.tail.prev = self.head;
}

pub fn deinit(self: *List, allocator: std.mem.Allocator) void {
    var current_optional: ?*Node = self.head;
    while (current_optional) |current| {
        const node: *Node = current;
        current_optional = current.next;

        node.deinit(allocator);
        allocator.destroy(node);
    }
}

pub fn push_front(self: *List, node: *Node) bool {
    assert.cheap(node.prev == null);
    assert.cheap(node.next == null);
    assert.cheap(node != self.head);
    assert.cheap(node != self.tail);

    const prev: *Node = self.head;
    const next: *Node = self.head.next orelse return false;
    insert(prev, next, node);

    self.size = self.size + 1;

    return true;
}

pub fn pop_front(self: *List) ?*Node {
    if (self.size == 0) return null;

    const node: *Node = self.head.next orelse return null;
    if (node == self.head or node == self.tail) return null;

    const prev: *Node = node.prev orelse return null;
    const next: *Node = node.next orelse return null;
    detach(prev, next, node);

    self.size = self.size - 1;

    return node;
}

// TODO: should return true on success, false on fail
pub fn push_back(self: *List, node: *Node) bool {
    assert.cheap(node.prev == null);
    assert.cheap(node.next == null);
    assert.cheap(node != self.head);
    assert.cheap(node != self.tail);

    const prev: *Node = self.tail.prev orelse return false;
    const next: *Node = self.tail;
    insert(prev, next, node);

    self.size = self.size + 1;

    return true;
}

// TODO: should return null on empty
// TODO: should return null on head or tail
pub fn pop_back(self: *List) ?*Node {
    if (self.size == 0) return null;

    const node: *Node = self.tail.prev orelse return null;
    if (node == self.head or node == self.tail) return null;

    const prev: *Node = node.prev orelse return null;
    const next: *Node = node.next orelse return null;
    detach(prev, next, node);

    self.size = self.size - 1;

    return node;
}

pub fn insert_after(self: *List, index: u32, node: *Node) bool {
    assert.cheap(node.prev == null);
    assert.cheap(node.next == null);
    assert.cheap(node != self.head);
    assert.cheap(node != self.tail);

    if (index >= self.size) return false;

    const target = self.lookup(index) orelse return false;
    const prev: *Node = target;
    const next: *Node = target.next orelse return false;
    insert(prev, next, node);

    self.size = self.size + 1;

    return true;
}

pub fn insert_before(self: *List, index: u32, node: *Node) bool {
    assert.cheap(node.prev == null);
    assert.cheap(node.next == null);
    assert.cheap(node != self.head);
    assert.cheap(node != self.tail);

    if (index >= self.size) return false;

    const target = self.lookup(index) orelse return false;
    const prev: *Node = target.prev orelse return false;
    const next: *Node = target;
    insert(prev, next, node);

    self.size = self.size + 1;

    return true;
}

pub fn remove(self: *List, index: u32) ?*Node {
    if (self.size == 0) return null;
    if (index >= self.size) return null;

    const node = self.lookup(index) orelse return null;
    const prev: *Node = node.prev orelse return null;
    const next: *Node = node.next orelse return null;
    detach(prev, next, node);

    self.size = self.size - 1;

    return node;
}

pub fn update(
    self: *List,
    allocator: std.mem.Allocator,
    index: u32,
    data: []const u8,
) !bool {
    if (self.size == 0) return false;
    if (index >= self.size) return false;

    const node = self.lookup(index) orelse return false;
    allocator.free(node.value);
    node.value = try allocator.dupe(u8, data);

    return true;
}

pub fn lookup(self: *List, index: u32) ?*Node {
    if (self.size == 0) return null;
    if (index >= self.size) return null;

    var current_optional: ?*Node = self.head.next;
    var i: u32 = 0;
    while (current_optional) |current| {
        if (i == index) return current;
        current_optional = current.next;
        i = i + 1;
    }

    return null;
}

// TODO: implement util function for insertion
fn insert(prev: *Node, next: *Node, node: *Node) void {
    prev.next = node;
    node.prev = prev;

    next.prev = node;
    node.next = next;
}

// TODO: implement util function for detaching
fn detach(prev: *Node, next: *Node, node: *Node) void {
    prev.next = next;
    next.prev = prev;

    node.prev = null;
    node.next = null;
}
