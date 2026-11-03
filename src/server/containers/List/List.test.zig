const std = @import("std");

const Node = @import("Node.zig");
const List = @import("List.zig");

// TODO: add errdefer fail message per test
// TODO: omit test numbering
// TODO: add whether or not test is positive or negative test
// TODO: implement elements validator
// TODO: implement helper for creating slice of nodes
// TODO: implement helper for destroying slice of nodes

const helper = struct {
    pub fn create_node(
        data: []const u8,
    ) !*Node {
        var node: *Node = try std.testing.allocator.create(Node);
        try node.init(std.testing.allocator, data);
        return node;
    }
    pub fn destroy_node(node: *Node) void {
        node.deinit(std.testing.allocator);
        std.testing.allocator.destroy(node);
    }
};

test "init" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.eql(u8, list.head.value, ""));
    try std.testing.expect(list.head.prev == null);
    try std.testing.expect(list.head.next.? == list.tail);

    try std.testing.expect(std.mem.eql(u8, list.tail.value, ""));
    try std.testing.expect(list.tail.prev.? == list.head);
    try std.testing.expect(list.tail.next == null);

    try std.testing.expect(list.size == 0);
}

test "push front with valid nodes" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    const result_a: bool = list.push_front(node_a);
    try std.testing.expect(result_a);
    try std.testing.expect(list.head.next.? == node_a);
    try std.testing.expect(list.tail.prev.? == node_a);
    try std.testing.expect(list.size == 1);

    const result_b: bool = list.push_front(node_b);
    try std.testing.expect(result_b);
    try std.testing.expect(list.head.next.? == node_b);
    try std.testing.expect(list.tail.prev.? == node_a);
    try std.testing.expect(list.size == 2);

    const result_c: bool = list.push_front(node_c);
    try std.testing.expect(result_c);
    try std.testing.expect(list.head.next.? == node_c);
    try std.testing.expect(list.tail.prev.? == node_a);
    try std.testing.expect(list.size == 3);
}

test "pop front on non-empty list" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_front(node_a);
    _ = list.push_front(node_b);
    _ = list.push_front(node_c);

    const pop_c: ?*Node = list.pop_front();
    defer helper.destroy_node(pop_c.?);

    try std.testing.expect(pop_c != null);
    try std.testing.expect(pop_c.?.prev == null);
    try std.testing.expect(pop_c.?.next == null);
    try std.testing.expect(list.head.next.? == node_b);
    try std.testing.expect(list.tail.prev.? == node_a);
    try std.testing.expect(list.size == 2);

    const pop_b: ?*Node = list.pop_front();
    defer helper.destroy_node(pop_b.?);

    try std.testing.expect(pop_b != null);
    try std.testing.expect(pop_b.?.prev == null);
    try std.testing.expect(pop_b.?.next == null);
    try std.testing.expect(list.head.next.? == node_a);
    try std.testing.expect(list.tail.prev.? == node_a);
    try std.testing.expect(list.size == 1);

    const pop_a: ?*Node = list.pop_front();
    defer helper.destroy_node(pop_a.?);

    try std.testing.expect(pop_a != null);
    try std.testing.expect(pop_a.?.prev == null);
    try std.testing.expect(pop_a.?.next == null);
    try std.testing.expect(list.head.next.? == list.tail);
    try std.testing.expect(list.tail.prev.? == list.head);
    try std.testing.expect(list.size == 0);
}

test "push back with valid nodes" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    const result_a: bool = list.push_back(node_a);
    try std.testing.expect(result_a);
    try std.testing.expect(list.head.next.? == node_a);
    try std.testing.expect(list.tail.prev.? == node_a);
    try std.testing.expect(list.size == 1);

    const result_b: bool = list.push_back(node_b);
    try std.testing.expect(result_b);
    try std.testing.expect(list.head.next.? == node_a);
    try std.testing.expect(list.tail.prev.? == node_b);
    try std.testing.expect(list.size == 2);

    const result_c: bool = list.push_back(node_c);
    try std.testing.expect(result_c);
    try std.testing.expect(list.head.next.? == node_a);
    try std.testing.expect(list.tail.prev.? == node_c);
    try std.testing.expect(list.size == 3);
}

test "pop back on non-empty list" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    const pop_c: ?*Node = list.pop_back();
    defer helper.destroy_node(pop_c.?);

    try std.testing.expect(pop_c != null);
    try std.testing.expect(pop_c.?.prev == null);
    try std.testing.expect(pop_c.?.next == null);
    try std.testing.expect(list.head.next.? == node_a);
    try std.testing.expect(list.tail.prev.? == node_b);
    try std.testing.expect(list.size == 2);

    const pop_b: ?*Node = list.pop_back();
    defer helper.destroy_node(pop_b.?);

    try std.testing.expect(pop_b != null);
    try std.testing.expect(pop_b.?.prev == null);
    try std.testing.expect(pop_b.?.next == null);
    try std.testing.expect(list.head.next.? == node_a);
    try std.testing.expect(list.tail.prev.? == node_a);
    try std.testing.expect(list.size == 1);

    const pop_a: ?*Node = list.pop_back();
    defer helper.destroy_node(pop_a.?);

    try std.testing.expect(pop_a != null);
    try std.testing.expect(pop_a.?.prev == null);
    try std.testing.expect(pop_a.?.next == null);
    try std.testing.expect(list.head.next.? == list.tail);
    try std.testing.expect(list.tail.prev.? == list.head);
    try std.testing.expect(list.size == 0);
}

test "insert after on valid index" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    const node_d: *Node = try helper.create_node("node_d");
    const node_e: *Node = try helper.create_node("node_e");

    const result_d: bool = list.insert_after(0, node_d);
    try std.testing.expect(result_d);
    try std.testing.expect(list.head.next.?.next.? == node_d);
    try std.testing.expect(list.head.next.?.next.?.prev.? == node_a);
    try std.testing.expect(list.head.next.?.next.?.next.? == node_b);
    try std.testing.expect(list.size == 4);

    const result_e: bool = list.insert_after(1, node_e);
    try std.testing.expect(result_e);
    try std.testing.expect(list.head.next.?.next.?.next.? == node_e);
    try std.testing.expect(list.head.next.?.next.?.next.?.prev.? == node_d);
    try std.testing.expect(list.head.next.?.next.?.next.?.next.? == node_b);
    try std.testing.expect(list.size == 5);
}

test "insert after on invalid index" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    const node_d: *Node = try helper.create_node("node_d");
    defer helper.destroy_node(node_d);

    const result_d: bool = list.insert_after(8, node_d);
    try std.testing.expect(result_d == false);
}

test "insert before on valid index" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    const node_d: *Node = try helper.create_node("node_d");
    const node_e: *Node = try helper.create_node("node_e");

    const result_d: bool = list.insert_before(0, node_d);
    try std.testing.expect(result_d);
    try std.testing.expect(list.head.next.? == node_d);
    try std.testing.expect(list.head.next.?.prev.? == list.head);
    try std.testing.expect(list.head.next.?.next.? == node_a);
    try std.testing.expect(list.size == 4);

    const result_e: bool = list.insert_before(1, node_e);
    try std.testing.expect(result_e);
    try std.testing.expect(list.head.next.?.next.? == node_e);
    try std.testing.expect(list.head.next.?.next.?.prev.? == node_d);
    try std.testing.expect(list.head.next.?.next.?.next.? == node_a);
    try std.testing.expect(list.size == 5);
}

test "insert before on invalid index" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    const node_d: *Node = try helper.create_node("node_d");
    defer helper.destroy_node(node_d);

    const result_d: bool = list.insert_before(8, node_d);
    try std.testing.expect(result_d == false);
}

test "remove with non-empty list and valid index" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    const remove_b: ?*Node = list.remove(1);
    defer helper.destroy_node(remove_b.?);

    try std.testing.expect(remove_b != null);
    try std.testing.expect(remove_b.?.prev == null);
    try std.testing.expect(remove_b.?.next == null);
    try std.testing.expect(list.head.next.?.next.? == node_c);
    try std.testing.expect(list.size == 2);
}

test "remove with empty list" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const remove_b: ?*Node = list.remove(0);
    try std.testing.expect(remove_b == null);
}

test "remove with invalid index" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    const remove: ?*Node = list.remove(8);
    try std.testing.expect(remove == null);
}

test "update element with non-empty list and valid index" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    const result: bool = try list.update(std.testing.allocator, 2, "node_d");
    try std.testing.expect(result);
    try std.testing.expect(std.mem.eql(u8, list.tail.prev.?.value, "node_d"));
    try std.testing.expect(std.mem.eql(u8, node_c.value, "node_d"));
}

test "update element with empty list" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const result: bool = try list.update(std.testing.allocator, 8, "node_d");
    try std.testing.expect(result == false);
}

test "update element with invalid index" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    const result: bool = try list.update(std.testing.allocator, 8, "node_d");
    try std.testing.expect(result == false);
}

test "lookup with non-empty list and valid index" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    try std.testing.expect(list.lookup(0).? == node_a);
    try std.testing.expect(list.lookup(1).? == node_b);
    try std.testing.expect(list.lookup(2).? == node_c);
}

test "lookup with empty list" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    try std.testing.expect(list.lookup(0) == null);
}

test "lookup with invalid index" {
    var list: *List = try std.testing.allocator.create(List);
    defer std.testing.allocator.destroy(list);

    try list.init(std.testing.allocator);
    defer list.deinit(std.testing.allocator);

    const node_a: *Node = try helper.create_node("node_a");
    const node_b: *Node = try helper.create_node("node_b");
    const node_c: *Node = try helper.create_node("node_c");

    _ = list.push_back(node_a);
    _ = list.push_back(node_b);
    _ = list.push_back(node_c);

    try std.testing.expect(list.lookup(8) == null);
}
