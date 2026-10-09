// standard library, library, and module imports
const std = @import("std");
const sys = @import("sys");
const protocol = @import("protocol");

// file imports
const assert = @import("assert");

// aliases
const Allocator = std.mem.Allocator;
const linux = std.os.linux;
const log = std.log.scoped(.net_client);

/// `Client` abstracts the handling of client connections, reading from and writing
/// to socket buffers
const Client = @This();

pub const State = enum {
    receive,
    send,
    close,
};

socket: i32,
state_current: State, // action the client is performing (e.g. read, write, etc.)
state_desired: State, // next action client wants to perform (e.g. read, write, etc.)
buffer_receive: std.ArrayList(u8), // bytes from socket receive buffer for processing
buffeer_send: std.ArrayList(u8), // bytes for socket send buffer for sending

/// Initializes an existing `Client` instance.
pub fn init(self: *Client, connection_fd: i32) void {
    assert.cheap(connection_fd >= 0);

    self.* = .{
        .socket = connection_fd,
        .state_current = .receive,
        .state_desired = .receive,
        .buffer_receive = .empty,
        .buffeer_send = .empty,
    };
    log.debug("client initialized", .{});
}

/// Deinitializes a `Client` instance and frees any memory allocations made by the
/// `Client` instance.
pub fn deinit(self: *Client, gpa: Allocator) void {
    assert.cheap(self.socket >= 0);
    assert.cheap(self.state_current != .close);

    sys.linux.close(self.socket) catch |err| switch (err) {
        error.Interrupted => {},
        error.Unexpected => {
            @panic("close() failed, unexpected error");
        },
    };

    self.socket = -1;
    self.state_current = .close;
    self.buffer_receive.deinit(gpa);
    self.buffeer_send.deinit(gpa);
    log.debug("client deinitialized", .{});
}

/// Receives bytes that comprise a request from the socket receive buffer and
/// queues the bytes into a buffer for request parsing and dispatching.
pub fn receive_requests(self: *Client, gpa: Allocator) void {
    assert.cheap(self.state_current == .receive);

    var buffer: [16 * 1024]u8 = undefined;

    const bytes_read_count: usize = sys.linux.recv(
        self.socket,
        &buffer,
        0,
    ) catch |err| switch (err) {
        error.EndOfStream => {
            if (self.buffer_receive.items.len == 0) {
                log.debug("client disconnected: fd={d}", .{self.socket});
            } else {
                log.debug("unexpected end of file: fd={d}", .{self.socket});
            }
            self.state_desired = .close;
            return;
        },
        error.WouldBlock, error.Interrupted => {
            return;
        },
        error.SystemResourcesExhausted => {
            log.debug("read() failed, {}: fd={d}, memory full", .{
                err,
                self.socket,
            });
            self.state_desired = .close;
            return;
        },
        error.ConnectionResetByPeer,
        error.ConnectionRefusedByPeer,
        => {
            log.debug("read() failed, {}: fd={d}", .{ err, self.socket });
            self.state_desired = .close;
            return;
        },
        error.Unexpected => {
            self.state_desired = .close;
            return;
        },
    };

    self.buffer_receive.appendSlice(gpa, buffer[0..bytes_read_count]) catch |err| {
        log.err(
            "appending message bytes failed: fd={d} error={}",
            .{ self.socket, err },
        );
        self.state_desired = .close;
        return;
    };

    while (self.process_request(gpa)) {}

    if (self.buffeer_send.items.len > 0) {
        self.state_current = .send;
        self.state_desired = .send;
        self.send_responses();
    } else {
        self.state_desired = .send;
    }
}

/// Sends the queued bytes that comprise a response to the socket send buffer for
/// responding to the connected peer's request.
pub fn send_responses(self: *Client) void {
    assert.cheap(self.state_current == .send);
    assert.cheap(self.buffeer_send.items.len > 0);

    const bytes_written_count: usize = sys.linux.send(
        self.socket,
        self.buffeer_send.items,
        linux.MSG.NOSIGNAL,
    ) catch |err| switch (err) {
        error.WouldBlock, error.Interrupted => {
            return;
        },
        error.SystemResourcesExhausted => {
            log.debug(
                "write() failed, {}: fd={d}, memory full",
                .{ err, self.socket },
            );
            self.state_desired = .close;
            return;
        },
        error.BrokenPipe,
        error.ConnectionResetByPeer,
        error.ConnectionRefusedByPeer,
        => {
            log.debug("write() failed, {}: fd={d}", .{ err, self.socket });
            self.state_desired = .close;
            return;
        },
        error.Unexpected => {
            @panic("write() failed, unexpected error");
        },
    };

    self.buffeer_send.replaceRangeAssumeCapacity(0, bytes_written_count, &.{});

    if (self.buffeer_send.items.len == 0) {
        self.state_desired = .receive;
    }
}

/// Parses the queued bytes into a complete request, dispatches the complete request,
/// and queues the results of the dispatched request into a buffer for
/// sending/responding back to the connected peer.
fn process_request(self: *Client, gpa: Allocator) bool {
    if (self.buffer_receive.items.len < protocol.header_length) {
        return false;
    }

    const header = self.buffer_receive.items[0..protocol.header_length];
    const body_length: u32 = std.mem.readInt(u32, header, .little);
    if (body_length > protocol.body_length_max) {
        self.state_desired = .close;
        return false;
    }

    const message_length: u32 = protocol.header_length + body_length;
    if (message_length > self.buffer_receive.items.len) {
        return false;
    }

    const body = self.buffer_receive.items[protocol.header_length..message_length];
    log.info("Client: {s}", .{body});
    self.buffeer_send.ensureUnusedCapacity(gpa, message_length) catch |err| {
        log.err(
            "reserving outgoing memory for message failed, {}: fd={d}",
            .{ err, self.socket },
        );
        self.state_desired = .close;
        return false;
    };
    self.buffeer_send.appendSliceAssumeCapacity(header);
    self.buffeer_send.appendSliceAssumeCapacity(body);
    self.buffer_receive.replaceRangeAssumeCapacity(0, message_length, &.{});

    return true;
}
