// standard library, library, and module imports
const std = @import("std");
const assert = @import("assert");

// file imports
const admin = @import("commands/admin.zig");
const connection = @import("commands/connection.zig");
const keyspace = @import("commands/keyspace.zig");
const string = @import("commands/string.zig");
const common = @import("commands/common.zig");

pub const Arity = common.Arity;

pub const Command = union(enum) {
    pub const Connection = connection.Connection;
    pub const Admin = admin.Admin;

    pub const Keyspace = keyspace.Keyspace;
    pub const String = string.String;

    // database commands
    admin: Admin,
    connection: Connection,

    // data commands
    keyspace: Keyspace,
    string: String,

    // unknown command opcode
    unknown: u16,

    pub fn decode(opcode: u16) Command {
        switch (opcode) {
            Connection.min...Connection.max => {
                return resolve(Connection, "connection", opcode);
            },
            Admin.min...Admin.max => {
                return resolve(Admin, "admin", opcode);
            },
            Keyspace.min...Keyspace.max => {
                return resolve(Keyspace, "keyspace", opcode);
            },
            String.min...String.max => {
                return resolve(String, "string", opcode);
            },
            else => {
                return .{ .unknown = opcode };
            },
        }
    }

    pub fn encode(self: Command) u16 {
        return switch (self) {
            .unknown => |raw| raw,
            inline else => |family_command| @intFromEnum(family_command),
        };
    }

    pub fn arity(self: Command) Arity {
        return switch (self) {
            .unknown => Arity{ .min = 0, .max = 0 },
            inline else => |command_family| @TypeOf(command_family).arity.get(command_family),
        };
    }

    fn resolve(comptime T: type, comptime field: []const u8, opcode: u16) Command {
        inline for (@typeInfo(T).@"enum".fields) |T_field| {
            if (T_field.value == opcode) {
                return @unionInit(Command, field, @enumFromInt(opcode));
            }
        }
        return .{ .unknown = opcode };
    }
};

comptime {
    for (@typeInfo(Command).@"union".fields) |field| {
        const T: type = field.type;

        if (@typeInfo(T) != .@"enum") continue;

        // tag_type validation
        assert.static(@typeInfo(T).@"enum".tag_type == u16);

        // declaration valdiation
        assert.static(@hasDecl(T, "min"));
        assert.static(@hasDecl(T, "max"));
        assert.static(@hasDecl(T, "arity"));

        // declaration type validation
        assert.static(@TypeOf(T.min) == u16);
        assert.static(@TypeOf(T.max) == u16);
        assert.static(@TypeOf(T.arity) == std.EnumArray(T, Arity));

        // declaration value validation
        assert.static(T.min < T.max);
        assert.static((T.max - T.min + 1) == 200);

        // type fields validation
        for (@typeInfo(T).@"enum".fields) |T_field| {
            assert.static(T_field.value >= T.min and T_field.value <= T.max);
        }
    }

    // collision validation
    for (@typeInfo(Command).@"union".fields) |field_a| {
        const T: type = field_a.type;
        if (@typeInfo(T) != .@"enum") continue;

        for (@typeInfo(Command).@"union".fields) |field_b| {
            const U: type = field_b.type;
            if (@typeInfo(U) != .@"enum") continue;

            if (T == U) continue;
            assert.static(T.min > U.max or T.max < U.min);
        }
    }

    // hole validation
    var min_lowest: u32 = std.math.maxInt(u32);
    var max_highest: u32 = 0;
    var stride_total: u32 = 0;
    for (@typeInfo(Command).@"union".fields) |field| {
        const T: type = field.type;
        if (@typeInfo(T) != .@"enum") continue;

        min_lowest = @min(min_lowest, T.min);
        max_highest = @max(max_highest, T.max);
        stride_total = stride_total + (T.max - T.min + 1);
    }
    assert.static(min_lowest == 0);
    assert.static(stride_total == max_highest + 1);
}
