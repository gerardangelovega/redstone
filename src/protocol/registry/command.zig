const std = @import("std");
const assert = @import("assert");

pub const Arity = struct {
    min: u32,
    max: u32,

    pub fn contains(self: *const Arity, n: u32) bool {
        return n >= self.min and n <= self.max;
    }
};

pub const Command = union(enum) {
    connection: Connection,
    server: Server,
    key: Key,
    string: String,
    unknown: u16,

    pub fn decode(code: u16) Command {
        switch (code) {
            Connection.min...Connection.max => {
                return decode_family(Connection, code);
            },
            Server.min...Server.max => {
                return decode_family(Server, code);
            },
            Key.min...Key.max => {
                return decode_family(Key, code);
            },
            String.min...String.max => {
                return decode_family(String, code);
            },
            else => {
                return .{ .unknown = code };
            },
        }
    }

    fn decode_family(comptime T: type, code: u16) Command {
        const tag = std.enums.fromInt(T, code) orelse return .{ .unknown = code };
        return @unionInit(Command, decode_family_field(T), tag);
    }

    fn decode_family_field(comptime T: type) []const u8 {
        const u = @typeInfo(Command).@"union";
        inline for (u.field_types, u.field_names) |U, name| {
            if (U == T) return name;
        }
        @compileError("decode_family_field() failed: field does not exist in " ++ @typeName(T));
    }

    pub fn encode(self: Command) u16 {
        switch (self) {
            .unknown => |code| {
                return code;
            },
            inline else => |command_family| {
                return @backingInt(command_family);
            },
        }
    }

    pub fn arity(self: Command) Arity {
        switch (self) {
            .unknown => {
                return .{ .min = 0, .max = 0 };
            },
            inline else => |command_family| {
                return @TypeOf(command_family).arities.get(command_family);
            },
        }
    }

    pub const Connection = enum(u16) {
        invalid = 0,
        ping = 1,
        echo = 2,

        pub const min: u16 = 0;
        pub const max: u16 = 199;

        pub const arities: std.EnumArray(@This(), Arity) = .init(.{
            .invalid = .{ .min = 0, .max = 0 },
            .ping = .{ .min = 0, .max = 0 },
            .echo = .{ .min = 1, .max = 1 },
        });
    };

    pub const Server = enum(u16) {
        info = 200,

        pub const min: u16 = 200;
        pub const max: u16 = 399;

        pub const arities: std.EnumArray(@This(), Arity) = .init(.{
            .info = .{ .min = 0, .max = 0 },
        });
    };

    pub const Key = enum(u16) {
        delete = 400,
        exists = 401,
        expire = 402,

        pub const min: u16 = 400;
        pub const max: u16 = 599;

        pub const arities: std.EnumArray(@This(), Arity) = .init(.{
            .delete = .{ .min = 1, .max = 1 },
            .exists = .{ .min = 1, .max = 1 },
            .expire = .{ .min = 2, .max = 2 },
        });
    };

    pub const String = enum(u16) {
        get = 600,
        set = 601,

        pub const min: u16 = 600;
        pub const max: u16 = 799;

        pub const arities: std.EnumArray(@This(), Arity) = .init(.{
            .get = .{ .min = 1, .max = 1 },
            .set = .{ .min = 2, .max = 2 },
        });
    };

    comptime {
        const u = @typeInfo(Command).@"union";

        for (u.field_types) |T| {
            if (@typeInfo(T) != .@"enum") continue;

            // tag_type validation
            assert.static(@typeInfo(T).@"enum".tag_type == u16);

            // declaration validation
            assert.static(@hasDecl(T, "min"));
            assert.static(@hasDecl(T, "max"));
            assert.static(@hasDecl(T, "arities"));

            // declaration type validation
            assert.static(@TypeOf(T.min) == u16);
            assert.static(@TypeOf(T.max) == u16);
            assert.static(@TypeOf(T.arities) == std.EnumArray(T, Arity));

            // declaration value validation
            assert.static(T.min < T.max);
            assert.static((T.max - T.min + 1) == 200);

            // type fields validation
            const e = @typeInfo(T).@"enum";
            for (e.field_values) |value| {
                assert.static(value >= T.min and value <= T.max);
            }
        }

        // collision validation
        for (u.field_types) |T| {
            if (@typeInfo(T) != .@"enum") continue;

            for (u.field_types) |U| {
                if (@typeInfo(U) != .@"enum") continue;

                if (T == U) continue;
                assert.static(T.min > U.max or T.max < U.min);
            }
        }

        // hole validation
        var min_lowest: u32 = std.math.maxInt(u32);
        var max_highest: u32 = 0;
        var stride_total: u32 = 0;
        for (u.field_types) |T| {
            if (@typeInfo(T) != .@"enum") continue;

            min_lowest = @min(min_lowest, T.min);
            max_highest = @max(max_highest, T.max);
            stride_total = stride_total + (T.max - T.min + 1);
        }
        assert.static(min_lowest == 0);
        assert.static(stride_total == max_highest + 1);
    }
};
