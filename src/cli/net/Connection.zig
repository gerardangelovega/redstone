// standard library, library, and module imports
const std = @import("std");
const sys = @import("sys");
const protocol = @import("protocol");

// aliases
const Allocator = std.mem.Allocator;
const assert = @import("assert");
const linux = std.os.linux;
const log = std.log.scoped(.net_connection);

const Connection = @This();

socket: i32,
buffer_receive: std.ArrayList(u8),
buffer_send: std.ArrayList(u8),

/// Initializes an existing `Connection` instance.
pub fn init(self: *Connection) void {
    self.* = .{
        .socket = undefined,
        .buffer_receive = .empty,
        .buffer_send = .empty,
    };

    const socket_fd: i32 = sys.linux.socket(
        linux.AF.INET,
        linux.SOCK.STREAM,
        linux.IPPROTO.TCP,
    ) catch |err| switch (err) {
        error.ProcessFdLimitExceeded => {
            log.err("socket() failed: {}: process limit is ?", .{err});
            std.process.exit(1);
        },
        error.SystemFdLimitExceeded => {
            log.err("socket() failed: {}: check /proc/sys/fs/file-max", .{err});
            std.process.exit(1);
        },
        error.SystemResourcesExhausted => {
            log.err("socket() failed: {}: memory/socket buffers full", .{err});
            std.process.exit(1);
        },
        error.Unexpected => {
            @panic("socket() falied, unexpected error");
        },
    };

    self.socket = socket_fd;
}

/// Deinitializes a `Connection` instance and frees any memory allocations made by the
/// `Connection` instance.
pub fn deinit(self: *Connection, gpa: Allocator) void {
    sys.linux.close(self.socket) catch |err| switch (err) {
        error.Interrupted => {},
        error.Unexpected => {
            @panic("close() failed, unexpected error");
        },
    };

    self.socket = -1;
    self.buffer_receive.deinit(gpa);
    self.buffer_send.deinit(gpa);
}

/// Connects a `Connection` instance to a server provided the address and port of the
/// server.
pub fn connect(self: *Connection, addr: [4]u8, port: u16) void {
    var socket_address: linux.sockaddr.in = .{
        .family = linux.AF.INET,
        .port = std.mem.nativeTo(u16, port, .big),
        .addr = @bitCast(addr),
    };
    sys.linux.connect(self.socket, &socket_address) catch |err| switch (err) {
        // NOTE: exit process for now, plan to implement retry w/ timeout in the future
        error.Interrupted, error.WouldBlock => {
            std.process.exit(1);
        },
        error.PermissionDenied, error.AddressInUse, error.AddressNotAvailable => {
            std.process.exit(1);
        },
        error.ConnectionRefusedByPeer => {
            std.process.exit(1);
        },
        // NOTE: Connection pending, nothing to do but wait
        error.ConnectionPending => {
            return;
        },
        // NOTE: Connection already established, can do requests already
        error.ConnectedAlready => {
            return;
        },
        error.ConnectionTimedOut => {
            std.process.exit(1);
        },
        error.NetworkUnreachable => {
            std.process.exit(1);
        },
        error.Unexpected => {
            @panic("connect() failed, unexpected error");
        },
    };
}

/// Sends a request to the server provided a request `body` containing the contents of
/// the request.
pub fn send_request(
    self: *Connection,
    gpa: Allocator,
    request: *const protocol.message.Request,
) bool {
    // if (body.len > protocol.body_length_max) {
    //     return false;
    // }
    //
    // var header: [protocol.header_length]u8 = undefined;
    // std.mem.writeInt(u32, &header, @intCast(body.len), .little);
    //
    // const message_length = protocol.header_length + body.len;
    const request_bytes = gpa.alloc(u8, request.header.message_size) catch |err| {
        std.log.err(
            "memory allocation for request serialization failed: fd={d} error={}",
            .{ self.socket, err },
        );
        return false;
    };
    defer gpa.free(request_bytes);
    request.serialize(request_bytes);

    self.buffer_send.ensureUnusedCapacity(gpa, request.header.message_size) catch |err| {
        std.log.err(
            "reserving outgoing memory for message failed: fd={d} error={}",
            .{ self.socket, err },
        );
        return false;
    };
    self.buffer_send.appendSliceAssumeCapacity(request_bytes);

    var bytes_to_send = self.buffer_send.items[0..];
    while (bytes_to_send.len > 0) {
        const bytes_sent_count: usize = sys.linux.send(
            self.socket,
            self.buffer_send.items,
            linux.MSG.NOSIGNAL,
        ) catch |err| switch (err) {
            error.Interrupted, error.WouldBlock => {
                continue;
            },
            error.SystemResourcesExhausted => {
                return false;
            },
            error.BrokenPipe => {
                return false;
            },
            error.ConnectionResetByPeer => {
                return false;
            },
            error.ConnectionRefusedByPeer => {
                return false;
            },
            error.Unexpected => {
                @panic("send() failed, unexpected error");
            },
        };
        bytes_to_send = bytes_to_send[bytes_sent_count..];
    }

    self.buffer_send.replaceRangeAssumeCapacity(0, request.header.message_size, &.{});
    return true;
}

/// Receives a response from the server, parses the response, and logs the body of the
/// parsed response.
pub fn receive_response(self: *Connection, gpa: Allocator) bool {
    const header_size = protocol.message.Response.Header.size;
    self.buffer_receive.appendNTimes(gpa, 0, header_size) catch |err| {
        std.log.err(
            "reserving incoming memory for header failed: fd={d} error={}",
            .{ self.socket, err },
        );
        return false;
    };

    var header_bytes_to_read: []u8 = self.buffer_receive.items[0..header_size];
    while (header_bytes_to_read.len > 0) {
        const bytes_read_count: usize = sys.linux.recv(
            self.socket,
            header_bytes_to_read,
            0,
        ) catch |err| switch (err) {
            error.EndOfStream => {
                break;
            },
            error.WouldBlock, error.Interrupted => {
                continue;
            },
            error.SystemResourcesExhausted => {
                return false;
            },
            error.ConnectionResetByPeer => {
                return false;
            },
            error.ConnectionRefusedByPeer => {
                return false;
            },
            error.Unexpected => {
                @panic("recv() failed, unexpected error");
            },
        };
        header_bytes_to_read = header_bytes_to_read[bytes_read_count..];
    }

    var response_header: protocol.message.Response.Header = undefined;
    response_header.parse(self.buffer_receive.items[0..header_size]);

    if (response_header.message_size > protocol.message.bytes_max) {
        return false;
    }

    self.buffer_receive.appendNTimes(gpa, 0, response_header.message_size) catch |err| {
        std.log.err(
            "reserving incoming memory for body failed: fd={d} error={}",
            .{ self.socket, err },
        );
        return false;
    };

    const message_size = response_header.message_size;

    var body_bytes_to_read = self.buffer_receive.items[header_size..message_size];
    while (body_bytes_to_read.len > 0) {
        const bytes_read_count: usize = sys.linux.recv(
            self.socket,
            body_bytes_to_read,
            0,
        ) catch |err| switch (err) {
            error.EndOfStream => {
                break;
            },
            error.WouldBlock, error.Interrupted => {
                continue;
            },
            error.SystemResourcesExhausted => {
                return false;
            },
            error.ConnectionResetByPeer => {
                return false;
            },
            error.ConnectionRefusedByPeer => {
                return false;
            },
            error.Unexpected => {
                @panic("read() failed, unexpected error");
            },
        };
        body_bytes_to_read = body_bytes_to_read[bytes_read_count..];
    }

    var response: protocol.message.Response = undefined;
    response.parse(gpa, self.buffer_receive.items[0..message_size]) catch |err| {
        std.log.err(
            "response parsing memory allocations failed: fd={d} error={}",
            .{ self.socket, err },
        );
        return false;
    };
    defer gpa.free(response.body.data);

    for (response.body.data) |datum| {
        switch (datum) {
            .nil => {
                std.log.debug("(nil)", .{});
            },
            .err => |val| {
                std.log.debug("(err) {s}", .{val});
            },
            .int => |val| {
                std.log.debug("(int) {d}", .{val});
            },
            .dbl => |val| {
                std.log.debug("(dbl) {d}", .{val});
            },
            .str => |val| {
                std.log.debug("(str) {s}", .{val});
            },
        }
    }

    self.buffer_receive.replaceRangeAssumeCapacity(0, message_size, &.{});

    return true;
}
