const std = @import("std");

const Request = @import("Request.zig");
const message = @import("../message.zig");

const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const RequestSerializer = @This();

backing_buffer: []u8,
fba: FixedBufferAllocator,
allocator: Allocator,

pub fn init(self: *RequestSerializer, gpa: Allocator) !void {
    self.backing_buffer = try gpa.alloc(u8, message.bytes_max);
    self.fba = FixedBufferAllocator.init(self.backing_buffer);
    self.allocator = self.fba.allocator();
}

pub fn deinit(self: *RequestSerializer, gpa: Allocator) void {
    self.fba.reset();
    gpa.free(self.backing_buffer);
}

pub fn reset(self: *RequestSerializer) void {
    self.fba.reset();
}

pub fn serialize(self: *RequestSerializer, request_in: *const Request, bytes_out: []u8) void {
    if (bytes_out.len != request_in.header.message_size) {
        return;
    }
    const header_bytes_out: []u8 = bytes_out[0..Request.Header.size];
    self.serialize_header(&request_in.header, header_bytes_out);

    const body_bytes_out: []u8 = bytes_out[Request.Header.size..];
    self.serialize_body(&request_in.body, body_bytes_out);
}

fn serialize_header(
    _: *RequestSerializer,
    header_in: *const Request.Header,
    header_bytes_out: []u8,
) void {
    var header_bytes_view: []u8 = header_bytes_out[0..];

    inline for (@typeInfo(Request.Header).@"struct".fields) |field| {
        const field_size = @sizeOf(field.type);
        std.mem.writeInt(
            field.type,
            header_bytes_view[0..field_size],
            @field(header_in, field.name),
            .little,
        );
        header_bytes_view = header_bytes_view[field_size..];
    }
}

fn serialize_body(
    _: *RequestSerializer,
    body_in: *const Request.Body,
    body_bytes_out: []u8,
) void {
    var body_bytes_view: []u8 = body_bytes_out[0..];

    for (body_in.data) |datum| {
        const tag_type = @typeInfo(@TypeOf(datum.tag)).@"enum".tag_type;
        const tag_size = @sizeOf(tag_type);
        std.mem.writeInt(
            tag_type,
            body_bytes_view[0..tag_size],
            @intFromEnum(datum.tag),
            .little,
        );
        body_bytes_view = body_bytes_view[tag_size..];

        switch (datum.value) {
            .nil => {}, // do nothing
            .int => |value| {
                const value_type = @TypeOf(value);
                const value_size = @sizeOf(value_type);
                std.mem.writeInt(
                    value_type,
                    body_bytes_view[0..value_size],
                    value,
                    .little,
                );
                body_bytes_view = body_bytes_view[value_size..];
            },
            .dbl => |value| {
                const value_bits: u64 = @bitCast(value);
                const value_type = @TypeOf(value_bits);
                const value_size = @sizeOf(value_type);
                std.mem.writeInt(
                    value_type,
                    body_bytes_view[0..value_size],
                    value_bits,
                    .little,
                );
                body_bytes_view = body_bytes_view[value_size..];
            },
            .err, .str => |value| {
                const length_type = @TypeOf(datum.length);
                const length_size = @sizeOf(length_type);
                std.mem.writeInt(
                    length_type,
                    body_bytes_view[0..length_size],
                    datum.length,
                    .little,
                );
                body_bytes_view = body_bytes_view[length_size..];

                @memcpy(body_bytes_view[0..value.len], value);
                body_bytes_view = body_bytes_view[value.len..];
            },
        }
    }
}
