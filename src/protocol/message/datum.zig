const std = @import("std");

pub const Datum = union(enum(u8)) {
    nil: void = 0,
    err: []const u8 = 1,
    int: i64 = 2,
    dbl: f64 = 3,
    str: []const u8 = 4,

    pub fn tag(self: *const Datum) u8 {
        return @intFromEnum(std.meta.activeTag(self.*));
    }

    pub fn length(self: *const Datum) u32 {
        switch (self.*) {
            .nil => {
                return 0;
            },
            .err => |value| {
                return @intCast(value.len);
            },
            .int => |value| {
                return @sizeOf(@TypeOf(value));
            },
            .dbl => |value| {
                return @sizeOf(@TypeOf(value));
            },
            .str => |value| {
                return @intCast(value.len);
            },
        }
    }

    pub fn size(self: *const Datum) u32 {
        var total_size: u32 = 0;

        const tag_type = std.meta.Tag(Datum);
        const tag_size: u32 = @sizeOf(tag_type);
        total_size = total_size + tag_size;

        switch (self.*) {
            .nil => {},
            .int, .dbl => {
                total_size = total_size + self.length();
            },
            .err, .str => {
                const value_length = self.length();
                const value_length_size = @sizeOf(@TypeOf(value_length));
                total_size = total_size + value_length_size + value_length;
            },
        }

        return total_size;
    }

    pub fn encode(self: *const Datum, bytes_out: []u8) void {
        var bytes_view: []u8 = bytes_out[0..];

        const datum_tag: u8 = self.tag();
        const datum_tag_type = @TypeOf(datum_tag);
        const datum_tag_size = @sizeOf(datum_tag_type);
        std.mem.writeInt(
            datum_tag_type,
            bytes_view[0..datum_tag_size],
            datum_tag,
            .little,
        );
        bytes_view = bytes_view[datum_tag_size..];

        switch (self.*) {
            .nil => {},
            .err => |value| {
                const datum_length = self.length();
                const datum_length_type = @TypeOf(datum_length);
                const datum_length_size = @sizeOf(datum_length_type);
                std.mem.writeInt(
                    datum_length_type,
                    bytes_view[0..datum_length_size],
                    datum_length,
                    .little,
                );
                bytes_view = bytes_view[datum_length_size..];

                @memcpy(bytes_view[0..value.len], value);
                bytes_view = bytes_view[value.len..];
            },
            .int => |value| {
                const datum_value_type = @TypeOf(value);
                const datum_value_size = @sizeOf(datum_value_type);
                std.mem.writeInt(
                    datum_value_type,
                    bytes_view[0..datum_value_size],
                    value,
                    .little,
                );
                bytes_view = bytes_view[datum_value_size..];
            },
            .dbl => |value| {
                const datum_value_bits: u64 = @bitCast(value);
                const datum_value_type = @TypeOf(datum_value_bits);
                const datum_value_size = @sizeOf(datum_value_type);
                std.mem.writeInt(
                    datum_value_type,
                    bytes_view[0..datum_value_size],
                    datum_value_bits,
                    .little,
                );
                bytes_view = bytes_view[datum_value_size..];
            },
            .str => |value| {
                const datum_length = self.length();
                const datum_length_type = @TypeOf(datum_length);
                const datum_length_size = @sizeOf(datum_length_type);
                std.mem.writeInt(
                    datum_length_type,
                    bytes_view[0..datum_length_size],
                    datum_length,
                    .little,
                );
                bytes_view = bytes_view[datum_length_size..];

                @memcpy(bytes_view[0..value.len], value);
                bytes_view = bytes_view[value.len..];
            },
        }
    }

    pub fn decode(self: *Datum, bytes_in: []const u8) void {
        var bytes_view: []const u8 = bytes_in[0..];

        const datum_tag_type = std.meta.Tag(Datum);
        const datum_tag_int_type = std.meta.Tag(datum_tag_type);
        const datum_tag_int_size = @sizeOf(datum_tag_int_type);
        const datum_tag: datum_tag_type = @enumFromInt(std.mem.readInt(
            datum_tag_int_type,
            bytes_view[0..datum_tag_int_size],
            .little,
        ));
        bytes_view = bytes_view[datum_tag_int_size..];

        switch (datum_tag) {
            .nil => {
                self.* = .{ .nil = {} };
            },
            .err => {
                const datum_length_type = u32;
                const datum_length_size = @sizeOf(datum_length_type);
                const datum_length = std.mem.readInt(
                    datum_length_type,
                    bytes_view[0..datum_length_size],
                    .little,
                );
                bytes_view = bytes_view[datum_length_size..];

                const datum_value = bytes_view[0..datum_length];
                bytes_view = bytes_view[datum_length..];

                self.* = .{ .err = datum_value };
            },
            .int => {
                const datum_value_type = @TypeOf(self.int);
                const datum_length = @sizeOf(datum_value_type);
                const datum_value = std.mem.readInt(
                    datum_value_type,
                    bytes_view[0..datum_length],
                    .little,
                );
                bytes_view = bytes_view[0..datum_length];

                self.* = .{ .int = datum_value };
            },
            .dbl => {
                const datum_length = @sizeOf(u64);
                const datum_value_bits: u64 = std.mem.readInt(
                    u64,
                    bytes_view[0..datum_length],
                    .little,
                );
                bytes_view = bytes_view[0..datum_length];
                const datum_value: f64 = @bitCast(datum_value_bits);

                self.* = .{ .dbl = datum_value };
            },
            .str => {
                const datum_length_type = u32;
                const datum_length_size = @sizeOf(datum_length_type);
                const datum_length = std.mem.readInt(
                    datum_length_type,
                    bytes_view[0..datum_length_size],
                    .little,
                );
                bytes_view = bytes_view[datum_length_size..];

                const datum_value = bytes_view[0..datum_length];
                bytes_view = bytes_view[datum_length..];

                self.* = .{ .str = datum_value };
            },
        }
    }
};
