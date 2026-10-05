const std = @import("std");
const linux = std.os.linux;
const log = std.log.scoped(.net_client);

const common = @import("common.zig");
const shared = @import("shared");

/// `Client` abstracts the handling of client connections, reading from and writing
/// to socket buffers
const Client = @This();

pub const State = enum { read, write, close };

socket: i32,
state_current: State,
state_desired: State,
incoming: std.ArrayList(u8),
outgoing: std.ArrayList(u8),

/// Initializes a `Client` struct by setting the `Client` fd to the provided fd
/// referencing a client connection
pub fn init(self: *Client, connection_fd: i32) void {
    std.debug.assert(connection_fd >= 0);

    self.* = .{
        .socket = connection_fd,
        .state_current = .read,
        .state_desired = .read,
        .incoming = .empty,
        .outgoing = .empty,
    };
    log.debug("client initialized", .{});
}

/// Deinitializes a `Client` struct by terminating client connection via closing
/// the `Client` fd and sets the `Client` fd to -1
pub fn deinit(self: *Client, gpa: std.mem.Allocator) void {
    std.debug.assert(self.socket >= 0);
    std.debug.assert(self.state_current != .close);

    common.fd_close(self.socket);

    self.socket = -1;
    self.state_current = .close;
    self.incoming.deinit(gpa);
    self.outgoing.deinit(gpa);
    log.debug("client deinitialized", .{});
}

pub fn read(self: *Client, gpa: std.mem.Allocator) void {
    var buffer: [16 * 1024]u8 = undefined;
    const rv: u64 = linux.read(self.socket, &buffer, buffer.len);
    switch (linux.errno(rv)) {
        .SUCCESS => {
            if (rv == 0) {
                if (self.incoming.items.len == 0) {
                    log.debug(
                        "client disconnected: fd={d}",
                        .{self.socket},
                    );
                } else {
                    log.debug(
                        "client disconnected mid-message: fd={d}",
                        .{self.socket},
                    );
                }
                self.state_desired = .close;
                return;
            }
        },
        .AGAIN => {
            log.debug("again", .{});
            return;
        }, // retry when socket receive buffer is not ready
        .INTR => {
            log.debug("intr", .{});
            return;
        }, // retry when interrupted
        .CONNRESET => {
            log.debug(
                "read() failed: fd={d} errno=CONNRESET, connection reset by peer",
                .{self.socket},
            );
            self.state_desired = .close;
            return;
        },
        else => |errno| {
            log.err(
                "read() failed: fd={d} errno={s}",
                .{ self.socket, @tagName(errno) },
            );
            self.state_desired = .close;
            return;
        },
    }

    self.incoming.appendSlice(gpa, buffer[0..rv]) catch |err| {
        log.err(
            "appending message bytes failed: fd={d} error={}",
            .{ self.socket, err },
        );
        self.state_desired = .close;
        return;
    };

    while (self.process(gpa)) {}

    self.state_desired = .write;
}

pub fn write(self: *Client) void {
    std.debug.assert(self.outgoing.items.len > 0);

    const rv: u64 = linux.write(
        self.socket,
        self.outgoing.items.ptr,
        self.outgoing.items.len,
    );
    switch (linux.errno(rv)) {
        .SUCCESS => {},
        .AGAIN => return, // retry when socket send buffer is not ready
        .INTR => return, // retry when interrupted
        .PIPE => {
            log.debug(
                "write() failed: fd={d} errno=PIPE, peer closed connection",
                .{self.socket},
            );
            self.state_desired = .close;
            return;
        },
        .CONNRESET => {
            log.debug(
                "write() failed: fd={d} errno=CONNRESET, connection reset by peer",
                .{self.socket},
            );
            self.state_desired = .close;
            return;
        },
        else => |errno| {
            log.err(
                "write() failed: fd={d} errno={s}",
                .{ self.socket, @tagName(errno) },
            );
            self.state_desired = .close;
            return;
        },
    }

    self.outgoing.replaceRangeAssumeCapacity(0, rv, &.{});

    self.state_desired = .read;
}

fn process(self: *Client, gpa: std.mem.Allocator) bool {
    const message = shared.protocol.message;

    if (self.incoming.items.len < message.header_length) {
        return false;
    }

    const header = self.incoming.items[0..message.header_length];
    const body_length: u32 = std.mem.readInt(u32, header, .little);
    if (body_length > message.body_length_max) {
        self.state_desired = .close;
        return false;
    }

    const message_length: u32 = message.header_length + body_length;
    if (message_length > self.incoming.items.len) {
        return false;
    }

    const body = self.incoming.items[message.header_length..message_length];
    log.info("Client: {s}", .{body});
    self.outgoing.ensureUnusedCapacity(gpa, message_length) catch |err| {
        log.err(
            "reserving outgoing memory for message failed: fd={d} error={}",
            .{ self.socket, err },
        );
        self.state_desired = .close;
        return false;
    };
    self.outgoing.appendSliceAssumeCapacity(header);
    self.outgoing.appendSliceAssumeCapacity(body);
    self.incoming.replaceRangeAssumeCapacity(0, message_length, &.{});

    return true;
}
