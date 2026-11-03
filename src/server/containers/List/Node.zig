const std = @import("std");

const Node = @This();

value: []const u8,
prev: ?*Node,
next: ?*Node,

pub fn init(self: *Node, allocator: std.mem.Allocator, data: []const u8) !void {
    self.* = .{
        .value = try allocator.dupe(u8, data),
        .prev = null,
        .next = null,
    };
}

pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
    allocator.free(self.value);
}
