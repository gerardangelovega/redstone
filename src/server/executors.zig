const std = @import("std");
const protocol = @import("protocol");

const Store = @import("Store.zig");
const connection = @import("executor/connection.zig").connection;
const string = @import("executor/string.zig").string;

const Command = protocol.registry.Command;
const Request = protocol.message.Request;
const Response = protocol.message.Response;

const log = std.log;

pub fn dispatch(
    allocator: std.mem.Allocator,
    store: *Store,
    command: Command,
    request_in: *const Request,
    response_out: *Response,
) bool {
    std.log.debug("dispatching command", .{});
    switch (command) {
        .connection => |c| {
            connection(allocator, c, request_in, response_out) catch |err| {
                log.debug("connection response init failed, {}", .{err});
                return false;
            };
        },
        .string => |s| {
            string(allocator, store, s, request_in, response_out) catch |err| {
                log.debug("string response init failed, {}", .{err});
                return false;
            };
        },
        else => {
            response_out.init(allocator, .err, &.{.{ .err = "unknown command" }}) catch |err| {
                log.debug("response initialization failed, {}", .{err});
                return false;
            };
        },
    }
    return true;
}
