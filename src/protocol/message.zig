const std = @import("std");

pub const data_max_count: u32 = std.math.maxInt(u16);
pub const bytes_max: u32 = 4 * 1024 * 1024;

pub const Datum = struct {
    tag: Tag,
    length: u32,
    value: Value,

    pub const Tag = enum(u8) {
        nil = 0,
        err = 1,
        int = 2,
        dbl = 3,
        str = 4,
    };

    pub const Value = union(Tag) {
        nil: void,
        err: []const u8,
        int: i64,
        dbl: f64,
        str: []const u8,
    };

    pub fn size(self: *const Datum) u32 {
        var total_size: u32 = 0;

        const tag_type = @typeInfo(@TypeOf(self.tag)).@"enum".tag_type;
        const tag_size: u32 = @sizeOf(tag_type);
        total_size = total_size + tag_size;

        switch (self.value) {
            .nil => {},
            .int => |value| {
                const value_type = @TypeOf(value);
                const value_size = @sizeOf(value_type);
                total_size = total_size + value_size;
            },
            .dbl => |value| {
                const value_type = @TypeOf(value);
                const value_size = @sizeOf(value_type);
                total_size = total_size + value_size;
            },
            .err, .str => |value| {
                const length_type = @TypeOf(self.length);
                const length_size = @sizeOf(length_type);
                total_size = total_size + length_size;
                total_size = total_size + @as(u32, @intCast(value.len));
            },
        }

        return total_size;
    }
};
