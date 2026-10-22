const std = @import("std");

const Request = @This();

const registry = @import("../registry.zig");
const message = @import("../message.zig");

header: Header,
body: Body,

// TODO: use Command instead of u16
pub fn init(self: *Request, command: registry.Command, data: []const message.Datum) void {
    self.body.data = data;
    self.body.size = 0;
    for (self.body.data) |datum| {
        self.body.size = self.body.size + datum.size();
    }

    self.header.message_size = Header.size + self.body.size;
    self.header.command_code = command.encode();
    self.header.data_count = @intCast(self.body.data.len);
}

// TODO: put parse and serializer here, I'm honestly overthinking it
pub fn parse(self: *Request, allocator: std.mem.Allocator, bytes_in: []const u8) !void {
    // Check if there are enough bytes to read at least the header.
    if (bytes_in.len < Request.Header.size) {
        return;
    }
    const header_bytes_in: []const u8 = bytes_in[0..Request.Header.size];
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
    try self.body.parse(allocator, body_bytes_in);

    // Check if the data count in the body is consistent with the data count in the header
    if (self.body.data.len != self.header.data_count) {
        return;
    }
    if (self.body.size + Request.Header.size != self.header.message_size) {
        return;
    }

    return;
}

pub fn serialize(self: *const Request, bytes_out: []u8) void {
    if (bytes_out.len != self.header.message_size) {
        return;
    }
    const header_bytes_out: []u8 = bytes_out[0..Request.Header.size];
    self.header.serialize(header_bytes_out);

    const body_bytes_out: []u8 = bytes_out[Request.Header.size..];
    self.body.serialize(body_bytes_out);

    return;
}

pub const Header = extern struct {
    pub const size: u32 = 8;

    message_size: u32,
    command_code: u16,
    data_count: u16,

    pub fn parse(self: *Header, bytes_in: []const u8) void {
        var bytes_view: []const u8 = bytes_in[0..];

        const s = @typeInfo(Header).@"struct";
        inline for (s.field_types, s.field_names) |T, name| {
            const field_size = @sizeOf(T);
            @field(self, name) = std.mem.readInt(
                T,
                bytes_view[0..field_size],
                .little,
            );
            bytes_view = bytes_view[field_size..];
        }
    }

    pub fn serialize(self: *const Header, bytes_out: []u8) void {
        var bytes_view: []u8 = bytes_out[0..];

        const s = @typeInfo(Header).@"struct";
        inline for (s.field_types, s.field_names) |T, name| {
            const field_size = @sizeOf(T);
            std.mem.writeInt(
                T,
                bytes_view[0..field_size],
                @field(self, name),
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
            datum.decode(bytes_view);
            try data.append(allocator, datum);

            bytes_view = bytes_view[datum.size()..];
            size = size + datum.size();
        }

        self.data = try data.toOwnedSlice(allocator);
        self.size = size;
    }

    pub fn serialize(self: *const Body, bytes_out: []u8) void {
        var bytes_view: []u8 = bytes_out[0..];

        for (self.data) |datum| {
            datum.encode(bytes_view);
            bytes_view = bytes_view[datum.size()..];
        }
    }
};
