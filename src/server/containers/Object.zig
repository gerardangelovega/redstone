const std = @import("std");
const assert = @import("assert");

const hash = @import("hash.zig");
const list = @import("list.zig");

/// `Object` is the basic unit of storage in the main in-memory key-value store and is
/// mainly used to retrieve the parent container to access the actual data.
const Object = @This();

kind: Kind,
hash_node: hash.Node,

pub fn from(hash_node: *hash.Node) *Object {
    return @fieldParentPtr("hash_node", hash_node);
}

pub const Kind = enum(u8) {
    string,
    list,
};

pub const String = struct {
    object: Object,
    string: []const u8,

    pub fn init(
        self: *String,
        allocator: std.mem.Allocator,
        key: []const u8,
        value: []const u8,
    ) !void {
        self.* = .{
            .object = .{
                .kind = .string,
                .hash_node = undefined,
            },
            .string = try allocator.dupe(u8, value),
        };
        self.object.hash_node.init(key);
    }

    /// Retrieve `String` instance from a `Object` pointer whose dereferenced value is
    /// owned by a `String` instance.
    pub fn from(object: *Object) *String {
        assert.cheap(object.kind == .string);

        return @fieldParentPtr("object", object);
    }
};

pub const List = struct {
    object: Object,
    list: list.List,

    pub fn init(
        self: *List,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) !void {
        self.* = .{
            .object = .{
                .kind = .list,
                .hash_node = undefined,
            },
            .list = undefined,
        };
        self.object.hash_node.init(key);
        try self.list.init(allocator);
    }

    pub fn from(object: *Object) *List {
        assert.cheap(object.kind == .list);

        return @fieldParentPtr("object", object);
    }
};
