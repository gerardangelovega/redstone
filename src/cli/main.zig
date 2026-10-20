// standard library, library, and module imports
const std = @import("std");
const protocol = @import("protocol");

// files
const net = @import("net.zig");

// aliases

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const command: protocol.registry.Command = .{ .key = .delete };
    _ = command;

    // SAFETY: defined and initialized by request.init();
    var request: protocol.message.Request = undefined;
    request.init(.{ .string = .get }, &.{
        .{ .str = "hello" },
        .{ .str = "world" },
    });

    std.log.debug("original request header: {any}", .{request.header});
    std.log.debug("original request body: {any}", .{request.body});
    std.log.debug("original request body data:", .{});
    for (request.body.data) |datum| {
        switch (datum) {
            .int => |val| {
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

    // request_serializer.serialize(&request, bytes);
    request.serialize(bytes);

    std.log.debug("serialized request in bytes: {x}", .{bytes});
    std.log.debug("", .{});

    // SAFETY: defined and initialized by request_parser.parse();
    var parsed_request: protocol.message.Request = undefined;
    try parsed_request.parse(gpa, bytes);
    // try request_parser.parse(bytes, &parsed_request);

    defer gpa.free(parsed_request.body.data);

    std.log.debug("parsed request header: {any}", .{parsed_request.header});
    std.log.debug("parsed request body: {any}", .{parsed_request.body});
    std.log.debug("parsed request body data:", .{});
    for (parsed_request.body.data) |datum| {
        switch (datum) {
            .int => |val| {
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
