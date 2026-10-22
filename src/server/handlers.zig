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
    response_out.init(
        .err,
        try gpa.dupe(protocol.message.Datum, &.{.{ .err = "invalid command" }}),
    );
}

fn ping(gpa: std.mem.Allocator, request_in: *const Request, response_out: *Response) !void {
    if (!Connection.arities.get(.ping).contains(request_in.header.data_count)) {
        response_out.init(
            .err,
            try gpa.dupe(protocol.message.Datum, &.{.{ .err = "bad arguments" }}),
        );
        return;
    }
    response_out.init(.ok, &.{.{ .str = "pong" }});
}

fn echo(gpa: std.mem.Allocator, request_in: *const Request, response_out: *Response) !void {
    if (!Connection.arities.get(.echo).contains(request_in.header.data_count)) {
        response_out.init(
            .err,
            try gpa.dupe(protocol.message.Datum, &.{.{ .err = "bad arguments" }}),
        );
        return;
    }
    if (request_in.body.data[0] != .str) {
        response_out.init(
            .err,
            try gpa.dupe(protocol.message.Datum, &.{.{ .err = "bad type, expected string" }}),
        );
        return;
    }
    response_out.init(
        .err,
        try gpa.dupe(protocol.message.Datum, &.{request_in.body.data[0]}),
    );
}
