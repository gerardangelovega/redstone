const std = @import("std");

const Request = @This();

const registry = @import("../registry.zig");
const message = @import("../message.zig");

header: Header,
body: Body,

// TODO: use Command instead of u16
pub fn init(self: *Request, command_code: u16, data: []const message.Datum) void {
    self.body.data = data;
    self.body.size = 0;
    for (self.body.data) |datum| {
        self.body.size = self.body.size + datum.size();
    }

    self.header.message_size = Header.size + self.body.size;
    self.header.command_code = command_code;
    self.header.data_count = @intCast(self.body.data.len);
}

// TODO: put parse and serializer here, I'm honestly overthinking it
pub fn parse(self: *Request, allocator: std.mem.Allocator, bytes_in: []const u8) !void {
    // Check if there are enough bytes to read at least the header.
    if (bytes_in.len < Request.Header.size) {
        return;
    }
    const header_bytes_in: []const u8 = bytes_in[0..Request.Header.size];
    // self.parse_header(header_bytes_in, &request_out.header);
    self.header.parse(header_bytes_in);

    // Check if there are enough bytes to read the entire message.
    if (bytes_in.len < self.header.message_size) {
        return;
    }

    // Check the validity of the command and its corresponding data.
    const command = registry.Command.decode(self.header.command_code);
    if (command == .unknown) {
        return;
    }
    if (command.arity().contains(self.header.data_count)) {
        return;
    }

    const body_bytes_begin = Request.Header.size;
    const body_bytes_end = self.header.message_size;
    const body_bytes_in: []const u8 = bytes_in[body_bytes_begin..body_bytes_end];
    // try self.parse_body(body_bytes_in, &request_out.body);
    try self.body.parse(allocator, body_bytes_in);

    // Check if the data count in the body is consistent with the data count in the header
    if (self.body.data.len != self.header.data_count) {
        return;
    }

    return;
}

pub fn serialize(self: *const Request, bytes_out: []u8) void {
    if (bytes_out.len != self.header.message_size) {
        return;
    }
    const header_bytes_out: []u8 = bytes_out[0..Request.Header.size];
    // self.serialize_header(self.header, header_bytes_out);
    self.header.serialize(header_bytes_out);

    const body_bytes_out: []u8 = bytes_out[Request.Header.size..];
    // self.serialize_body(&self.body, body_bytes_out);
    self.body.serialize(body_bytes_out);
}

pub const Header = extern struct {
    pub const size: u32 = 8;

    message_size: u32,
    command_code: u16,
    data_count: u16,

    pub fn parse(self: *Header, bytes_in: []const u8) void {
        var bytes_view: []const u8 = bytes_in[0..];

        inline for (@typeInfo(Header).@"struct".fields) |field| {
            const field_size = @sizeOf(field.type);
            @field(self, field.name) = std.mem.readInt(
                field.type,
                bytes_view[0..field_size],
                .little,
            );
            bytes_view = bytes_view[field_size..];
        }
    }

    pub fn serialize(self: *const Header, bytes_out: []u8) void {
        var bytes_view: []u8 = bytes_out[0..];

        inline for (@typeInfo(Request.Header).@"struct".fields) |field| {
            const field_size = @sizeOf(field.type);
            std.mem.writeInt(
                field.type,
                bytes_view[0..field_size],
                @field(self, field.name),
                .little,
            );
            bytes_view = bytes_view[field_size..];
        }
    }
};

pub const Body = struct {
    data: []const message.Datum,
    size: u32,

    pub fn parse(self: *Body, allocator: std.mem.Allocator, bytes_in: []const u8) !void {
        var bytes_view: []const u8 = bytes_in[0..];

        var data: std.ArrayList(message.Datum) = .empty;
        defer data.deinit(allocator);
        var size: u32 = 0;

        while (bytes_view.len > 0) {
            // SAFETY: defined in the following switch statement
            var datum: message.Datum = undefined;

            const tag_type = @typeInfo(@TypeOf(datum.tag)).@"enum".tag_type;
            const tag_size = @sizeOf(tag_type);
            datum.tag = @enumFromInt(std.mem.readInt(
                tag_type,
                bytes_view[0..tag_size],
                .little,
            ));
            bytes_view = bytes_view[tag_size..];
            size = size + tag_size;

            switch (datum.tag) {
                .nil => {
                    datum.length = 0;
                    datum.value = .{ .nil = {} };
                },
                .int => {
                    const length = @sizeOf(@TypeOf(datum.value.int));

                    const value_type = @TypeOf(datum.value.int);
                    const value: value_type = std.mem.readInt(
                        value_type,
                        bytes_view[0..length],
                        .little,
                    );
                    bytes_view = bytes_view[length..];
                    size = size + length;

                    datum.length = length;
                    datum.value = .{ .int = value };
                },
                .dbl => {
                    const length = @sizeOf(@TypeOf(datum.value.dbl));

                    const value_type = @TypeOf(datum.value.dbl);
                    const value: value_type = @bitCast(std.mem.readInt(
                        u64,
                        bytes_view[0..length],
                        .little,
                    ));
                    bytes_view = bytes_view[length..];
                    size = size + length;

                    datum.length = length;
                    datum.value = .{ .dbl = value };
                },
                .err, .str => {
                    const length_type = @TypeOf(datum.length);
                    const length_size = @sizeOf(length_type);
                    const length: length_type = std.mem.readInt(
                        length_type,
                        bytes_view[0..length_size],
                        .little,
                    );
                    bytes_view = bytes_view[length_size..];
                    size = size + length_size;

                    const value: []const u8 = bytes_view[0..length];
                    bytes_view = bytes_view[length..];
                    size = size + length;

                    datum.length = length;

                    if (datum.tag == .err) {
                        datum.value = .{ .err = try allocator.dupe(u8, value) };
                    } else if (datum.tag == .str) {
                        datum.value = .{ .str = try allocator.dupe(u8, value) };
                    }
                },
            }
            try data.append(allocator, datum);
        }

        self.data = try data.toOwnedSlice(allocator);
        self.size = size;
    }

    pub fn serialize(self: *const Body, bytes_out: []u8) void {
        var bytes_view: []u8 = bytes_out[0..];

        for (self.data) |datum| {
            const tag_type = @typeInfo(@TypeOf(datum.tag)).@"enum".tag_type;
            const tag_size = @sizeOf(tag_type);
            std.mem.writeInt(
                tag_type,
                bytes_view[0..tag_size],
                @intFromEnum(datum.tag),
                .little,
            );
            bytes_view = bytes_view[tag_size..];

            switch (datum.value) {
                .nil => {}, // do nothing
                .int => |value| {
                    const value_type = @TypeOf(value);
                    const value_size = @sizeOf(value_type);
                    std.mem.writeInt(
                        value_type,
                        bytes_view[0..value_size],
                        value,
                        .little,
                    );
                    bytes_view = bytes_view[value_size..];
                },
                .dbl => |value| {
                    const value_bits: u64 = @bitCast(value);
                    const value_type = @TypeOf(value_bits);
                    const value_size = @sizeOf(value_type);
                    std.mem.writeInt(
                        value_type,
                        bytes_view[0..value_size],
                        value_bits,
                        .little,
                    );
                    bytes_view = bytes_view[value_size..];
                },
                .err, .str => |value| {
                    const length_type = @TypeOf(datum.length);
                    const length_size = @sizeOf(length_type);
                    std.mem.writeInt(
                        length_type,
                        bytes_view[0..length_size],
                        datum.length,
                        .little,
                    );
                    bytes_view = bytes_view[length_size..];

                    @memcpy(bytes_view[0..value.len], value);
                    bytes_view = bytes_view[value.len..];
                },
            }
        }
    }
};
