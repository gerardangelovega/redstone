const std = @import("std");

const registry = @import("../registry.zig");
const message = @import("../message.zig");

const Response = @This();

header: Header,
body: Body,

pub fn init(self: *Response, status: registry.Status, data: []const message.Datum) void {
    self.body.data = data;
    self.body.size = 0;
    for (self.body.data) |datum| {
        self.body.size = self.body.size + datum.size();
    }

    self.header.message_size = Header.size + self.body.size;
    self.header.status_code = status.encode();
    self.header.data_count = @intCast(self.body.data.len);
}

pub fn deinit(self: *Response, allocator: std.mem.Allocator) void {
    allocator.free(self.body.data);
}

pub fn parse(self: *Response, allocator: std.mem.Allocator, bytes_in: []const u8) !void {
    if (bytes_in.len < Response.Header.size) {
        return;
    }
    const header_bytes_in: []const u8 = bytes_in[0..Response.Header.size];
    self.header.parse(header_bytes_in);

    if (bytes_in.len < self.header.message_size) {
        return;
    }

    const body_bytes_begin = Response.Header.size;
    const body_bytes_end = self.header.message_size;
    const body_bytes_in: []const u8 = bytes_in[body_bytes_begin..body_bytes_end];
    try self.body.parse(allocator, body_bytes_in);

    if (self.body.data.len != self.header.data_count) {
        return;
    }
    if (self.body.size + Response.Header.size != self.header.message_size) {
        return;
    }

    return;
}

pub fn serialize(self: *const Response, bytes_out: []u8) void {
    if (bytes_out.len != self.header.message_size) {
        return;
    }

    const header_bytes_out: []u8 = bytes_out[0..Response.Header.size];
    self.header.serialize(header_bytes_out);

    const body_bytes_out: []u8 = bytes_out[Response.Header.size..self.header.message_size];
    self.body.serialize(body_bytes_out);

    return;
}

pub const Header = extern struct {
    pub const size: u32 = 8;

    message_size: u32,
    status_code: u16,
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
            // SAFETY: initialized by decode()
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
