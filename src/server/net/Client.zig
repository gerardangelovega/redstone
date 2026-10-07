// standard library, library, and module imports
const std = @import("std");
const sys = @import("sys");
const protocol = @import("protocol");

// file imports
const common = @import("common.zig");

// aliases
const Allocator = std.mem.Allocator;
const linux = std.os.linux;
const log = std.log.scoped(.net_client);

/// `Client` abstracts the handling of client connections, reading from and writing
/// to socket buffers
const Client = @This();

// TODO2: rename enums to receive, send, and close
pub const State = enum { read, write, close };

socket: i32,
state_current: State, // action the client is performing (e.g. read, write, etc.)
state_desired: State, // next action client wants to perform (e.g. read, write, etc.)
incoming: std.ArrayList(u8), // buffer to store bytes read from receive buffer
outgoing: std.ArrayList(u8), // buffer to store bytes to write to send buffer

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
pub fn deinit(self: *Client, gpa: Allocator) void {
    std.debug.assert(self.socket >= 0);
    std.debug.assert(self.state_current != .close);

    sys.linux.close(self.socket) catch |err| switch (err) {
        error.Interrupted => {},
        error.Unexpected => {
            @panic("close() failed, unexpected error");
        },
    };

    self.socket = -1;
    self.state_current = .close;
    self.incoming.deinit(gpa);
    self.outgoing.deinit(gpa);
    log.debug("client deinitialized", .{});
}

// TODO2: rename to receive_request()

/// Reads bytes from the socket receive buffer and appends the read bytes into the
/// `Client`.`incoming` byte buffer.
pub fn read(self: *Client, gpa: Allocator) void {
    std.debug.assert(self.state_current == .read);

    var buffer: [16 * 1024]u8 = undefined;

    const bytes_read_count: usize = sys.linux.read(
        self.socket,
        &buffer,
        buffer.len,
    ) catch |err| switch (err) {
        error.EndOfStream => {
            if (self.incoming.items.len == 0) {
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
        error.ConnectionResetByPeer => {
            log.debug("read() failed, {}: fd={d}", .{ err, self.socket });
            self.state_desired = .close;
            return;
        },
        error.Unexpected => {
            self.state_desired = .close;
            return;
        },
    };

    self.incoming.appendSlice(gpa, buffer[0..bytes_read_count]) catch |err| {
        log.err(
            "appending message bytes failed: fd={d} error={}",
            .{ self.socket, err },
        );
        self.state_desired = .close;
        return;
    };

    while (self.process(gpa)) {}

    if (self.outgoing.items.len > 0) {
        self.state_current = .write;
        self.state_desired = .write;
        self.write();
    } else {
        self.state_desired = .write;
    }
}

// TODO2: rename to send_response()

/// Writes bytes from the `Client`.`outgoing` byte buffer into the socket send buffer
pub fn write(self: *Client) void {
    std.debug.assert(self.state_current == .write);
    std.debug.assert(self.outgoing.items.len > 0);

    const bytes_written_count: usize = sys.linux.write(
        self.socket,
        self.outgoing.items.ptr,
        self.outgoing.items.len,
    ) catch |err| switch (err) {
        error.WouldBlock, error.Interrupted => {
            return;
        },
        error.BrokenPipe, error.ConnectionResetByPeer => {
            log.debug("write() failed, {}: fd={d}", .{ err, self.socket });
            self.state_desired = .close;
            return;
        },
        error.Unexpected => {
            @panic("write() failed, unexpected error");
        },
    };

    self.outgoing.replaceRangeAssumeCapacity(0, bytes_written_count, &.{});

    if (self.outgoing.items.len == 0) {
        self.state_desired = .read;
    }
}

/// Drains the `Client`.`incoming` buffer into the `Client`.`outgoing`. Only drains a
/// stream of bytes from `Client`.`incoming` when the stream of bytes is a complete
/// message.
fn process(self: *Client, gpa: Allocator) bool {
    if (self.incoming.items.len < protocol.header_length_fixed) {
        return false;
    }

    const header = self.incoming.items[0..protocol.header_length_fixed];
    const body_length: u32 = std.mem.readInt(u32, header, .little);
    if (body_length > protocol.body_length_max) {
        self.state_desired = .close;
        return false;
    }

    const message_length: u32 = protocol.header_length_fixed + body_length;
    if (message_length > self.incoming.items.len) {
        return false;
    }

    const body = self.incoming.items[protocol.header_length_fixed..message_length];
    log.info("Client: {s}", .{body});
    self.outgoing.ensureUnusedCapacity(gpa, message_length) catch |err| {
        log.err(
            "reserving outgoing memory for message failed, {}: fd={d}",
            .{ err, self.socket },
        );
        self.state_desired = .close;
        return false;
    };
    self.outgoing.appendSliceAssumeCapacity(header);
    self.outgoing.appendSliceAssumeCapacity(body);
    self.incoming.replaceRangeAssumeCapacity(0, message_length, &.{});

    return true;
}
