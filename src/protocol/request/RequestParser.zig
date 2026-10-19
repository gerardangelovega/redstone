const std = @import("std");

const Request = @import("Request.zig");
const registry = @import("../registry.zig");
const message = @import("../message.zig");

const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const RequestParser = @This();

backing_buffer: []u8,
fba: FixedBufferAllocator,
allocator: Allocator,

pub fn init(self: *RequestParser, gpa: Allocator) !void {
    self.backing_buffer = try gpa.alloc(u8, @sizeOf(message.Datum) * message.data_max_count);
    self.fba = FixedBufferAllocator.init(self.backing_buffer);
    self.allocator = self.fba.allocator();
}

pub fn deinit(self: *RequestParser, gpa: Allocator) void {
    self.fba.reset();
    gpa.free(self.backing_buffer);
}

pub fn reset(self: *RequestParser) void {
    self.fba.reset();
}

pub fn parse(self: *RequestParser, bytes_in: []const u8, request_out: *Request) !void {
    // Check if there are enough bytes to read at least the header.
    if (bytes_in.len < Request.Header.size) {
        return;
    }
    const header_bytes_in: []const u8 = bytes_in[0..Request.Header.size];
    self.parse_header(header_bytes_in, &request_out.header);

    // Check if there are enough bytes to read the entire message.
    if (bytes_in.len < request_out.header.message_size) {
        return;
    }

    // Check the validity of the command and its corresponding data.
    const command = registry.Command.decode(request_out.header.command_code);
    if (command == .unknown) {
        return;
    }
    if (command.arity().contains(request_out.header.data_count)) {
        return;
    }

    const body_bytes_begin = Request.Header.size;
    const body_bytes_end = request_out.header.message_size;
    const body_bytes_in: []const u8 = bytes_in[body_bytes_begin..body_bytes_end];
    try self.parse_body(body_bytes_in, &request_out.body);

    // Check if the data count in the body is consistent with the data count in the header
    if (request_out.body.data.len != request_out.header.data_count) {
        return;
    }

    return;
}

fn parse_header(
    _: *RequestParser,
    header_bytes_in: []const u8,
    header_out: *Request.Header,
) void {
    var header_bytes_view: []const u8 = header_bytes_in[0..];

    inline for (@typeInfo(Request.Header).@"struct".fields) |field| {
        const field_size = @sizeOf(field.type);
        @field(header_out, field.name) = std.mem.readInt(
            field.type,
            header_bytes_view[0..field_size],
            .little,
        );
        header_bytes_view = header_bytes_view[field_size..];
    }
}

fn parse_body(
    self: *RequestParser,
    body_bytes_in: []const u8,
    body_out: *Request.Body,
) !void {
    var body_bytes_view: []const u8 = body_bytes_in[0..];

    var data: std.ArrayList(message.Datum) = .empty;
    var size: u32 = 0;

    defer data.deinit(self.allocator);

    while (body_bytes_view.len > 0) {
        // SAFETY: defined in the following switch statement
        var datum: message.Datum = undefined;

        const tag_type = @typeInfo(@TypeOf(datum.tag)).@"enum".tag_type;
        const tag_size = @sizeOf(tag_type);
        datum.tag = @enumFromInt(std.mem.readInt(
            tag_type,
            body_bytes_view[0..tag_size],
            .little,
        ));
        body_bytes_view = body_bytes_view[tag_size..];
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
                    body_bytes_view[0..length],
                    .little,
                );
                body_bytes_view = body_bytes_view[length..];
                size = size + length;

                datum.length = length;
                datum.value = .{ .int = value };
            },
            .dbl => {
                const length = @sizeOf(@TypeOf(datum.value.dbl));

                const value_type = @TypeOf(datum.value.dbl);
                const value: value_type = @bitCast(std.mem.readInt(
                    u64,
                    body_bytes_view[0..length],
                    .little,
                ));
                body_bytes_view = body_bytes_view[length..];
                size = size + length;

                datum.length = length;
                datum.value = .{ .dbl = value };
            },
            .err, .str => {
                const length_type = @TypeOf(datum.length);
                const length_size = @sizeOf(length_type);
                const length: length_type = std.mem.readInt(
                    length_type,
                    body_bytes_view[0..length_size],
                    .little,
                );
                body_bytes_view = body_bytes_view[length_size..];
                size = size + length_size;

                const value: []const u8 = body_bytes_view[0..length];
                body_bytes_view = body_bytes_view[length..];
                size = size + length;

                datum.length = length;

                if (datum.tag == .err) {
                    datum.value = .{ .err = try self.allocator.dupe(u8, value) };
                } else if (datum.tag == .str) {
                    datum.value = .{ .str = try self.allocator.dupe(u8, value) };
                }
            },
        }
        try data.append(self.allocator, datum);
    }

    body_out.data = try data.toOwnedSlice(self.allocator);
    body_out.size = size;
}
