const std = @import("std");

const protocol = @import("protocol");

const Connection = protocol.registry.Command.Connection;
const Request = protocol.message.Request;
const Response = protocol.message.Response;

pub fn connection(
    gpa: std.mem.Allocator,
    command: Connection,
    request_in: *const Request,
    response_out: *Response,
) !void {
    switch (command) {
        .invalid => {
            try invalid(gpa, request_in, response_out);
        },
        .ping => {
            try ping(gpa, request_in, response_out);
        },
        .echo => {
            try echo(gpa, request_in, response_out);
        },
    }
}

fn invalid(gpa: std.mem.Allocator, _: *const Request, response_out: *Response) !void {
    try response_out.init(gpa, .err, &.{.{ .err = "invalid command" }});
}

fn ping(gpa: std.mem.Allocator, request_in: *const Request, response_out: *Response) !void {
    if (!Connection.arities.get(.ping).contains(request_in.header.data_count)) {
        try response_out.init(gpa, .err, &.{.{ .err = "bad arguments" }});
        return;
    }
    try response_out.init(gpa, .ok, &.{.{ .str = "pong" }});
}

fn echo(gpa: std.mem.Allocator, request_in: *const Request, response_out: *Response) !void {
    if (!Connection.arities.get(.echo).contains(request_in.header.data_count)) {
        try response_out.init(gpa, .err, &.{.{ .err = "bad arguments" }});
        return;
    }
    if (request_in.body.data[0] != .str) {
        try response_out.init(gpa, .err, &.{.{ .err = "bad type, expected string" }});
        return;
    }
    try response_out.init(gpa, .err, &.{request_in.body.data[0]});
}
