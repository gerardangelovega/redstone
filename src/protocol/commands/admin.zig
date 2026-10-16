const std = @import("std");

const common = @import("common.zig");

pub const Admin = enum(u16) {
    pub const min: u16 = 200;
    pub const max: u16 = 399;

    pub const arity: std.EnumArray(@This(), common.Arity) = .init(.{
        .info = .{ .min = 0, .max = 0 },
    });

    info = 200,
};
