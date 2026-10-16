const std = @import("std");

const common = @import("common.zig");

pub const String = enum(u16) {
    pub const min: u16 = 600;
    pub const max: u16 = 799;

    pub const arity: std.EnumArray(@This(), common.Arity) = .init(.{
        .string_set = .{ .min = 2, .max = 2 },
    });

    string_set = 600,
};
