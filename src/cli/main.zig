// standard library, library, and module imports
const std = @import("std");
const protocol = @import("protocol");

// files
const net = @import("net.zig");

// aliases

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    // SAFETY: defined and initialized by request_parser.init();
    var request_parser: protocol.RequestParser = undefined;
    try request_parser.init(gpa);
    defer request_parser.deinit(gpa);

    std.log.debug(
        "request parser backing buffer size: {d}",
        .{request_parser.backing_buffer.len},
    );

    // SAFETY: defined and initialized by request_serializer.init();
    var request_serializer: protocol.RequestSerializer = undefined;
    try request_serializer.init(gpa);
    defer request_serializer.deinit(gpa);

    std.log.debug(
        "request serializer backing buffer size: {d}",
        .{request_serializer.backing_buffer.len},
    );
    std.log.debug("", .{});

    // SAFETY: defined and initialized by request.init();
    var request: protocol.Request = undefined;
    request.init(600, &.{
        .{
            .tag = .str,
            .length = 5,
            .value = .{ .str = "hello" },
        },
        .{
            .tag = .str,
            .length = 5,
            .value = .{ .str = "world" },
        },
    });

    std.log.debug("original request header: {any}", .{request.header});
    std.log.debug("original request body: {any}", .{request.body});
    std.log.debug("original request body data:", .{});
    for (request.body.data) |datum| {
        switch (datum.value) {
            .int,
            => |val| {
                std.log.debug("datum: {d}", .{val});
            },
            .dbl => |val| {
                std.log.debug("datum: {d}", .{val});
            },
            .err, .str => |val| {
                std.log.debug("datum: {s}", .{val});
            },
            else => {},
        }
    }

    std.log.debug("", .{});

    const bytes: []u8 = try gpa.alloc(u8, request.header.message_size);
    defer gpa.free(bytes);

    request_serializer.serialize(&request, bytes);

    std.log.debug("serialized request in bytes: {x}", .{bytes});
    std.log.debug("", .{});

    // SAFETY: defined and initialized by request_parser.parse();
    var parsed_request: protocol.Request = undefined;
    try request_parser.parse(bytes, &parsed_request);

    std.log.debug("parsed request header: {any}", .{parsed_request.header});
    std.log.debug("parsed request body: {any}", .{parsed_request.body});
    std.log.debug("parsed request body data:", .{});
    for (parsed_request.body.data) |datum| {
        switch (datum.value) {
            .int,
            => |val| {
                std.log.debug("datum: {d}", .{val});
            },
            .dbl => |val| {
                std.log.debug("datum: {d}", .{val});
            },
            .err, .str => |val| {
                std.log.debug("datum: {s}", .{val});
            },
            else => {},
        }
    }
}
