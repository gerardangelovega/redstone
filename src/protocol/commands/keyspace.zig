const std = @import("std");

const common = @import("common.zig");

pub const Keyspace = enum(u16) {
    pub const min: u16 = 400;
    pub const max: u16 = 599;

    pub const arity: std.EnumArray(@This(), common.Arity) = .init(.{
        .get = .{ .min = 1, .max = 1 },
        .del = .{ .min = 1, .max = 1 },
    });

    get = 400,
    del = 401,
};
