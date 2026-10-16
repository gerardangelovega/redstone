const std = @import("std");

const common = @import("common.zig");

pub const Connection = enum(u16) {
    pub const min: u16 = 0;
    pub const max: u16 = 199;

    pub const arity: std.EnumArray(@This(), common.Arity) = .init(.{
        .invalid = .{ .min = 0, .max = 0 },
        .ping = .{ .min = 0, .max = 0 },
        .echo = .{ .min = 1, .max = 1 },
    });

    invalid = 0,
    ping = 1,
    echo = 2,
};
