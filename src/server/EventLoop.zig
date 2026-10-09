// standard library, library, and module imports
const std = @import("std");
const sys = @import("sys");

// file imports
const assert = @import("assert");
const net = @import("net.zig");

// aliases
const Allocator = std.mem.Allocator;
const linux = std.os.linux;
const log = std.log.scoped(.event_loop);

/// `EventLoop` abstracts the main event loop of the program and the operations
/// involved in the main event loop as `EventLoop` methods.
const EventLoop = @This();

const State = enum {
    uninitialized,
    initialized,
    running,
    stopped,
    deinitialized,
};

listener: net.Listener,
epoll: net.io.Epoll,
clients: std.ArrayList(?*net.Client), // array map mapping fd as index to a net.Client
state: State,

/// Initializes an existing `EventLoop` instances along with its dependencies *(e.g. `net.Listener`, `net.Epoll`, etc.)*.
pub fn init(self: *EventLoop, gpa: Allocator) void {
    self.* = .{
        .listener = undefined,
        .epoll = undefined,
        .clients = undefined,
        .state = .uninitialized,
    };

    self.listener.init();
    self.listener.bind([4]u8{ 0, 0, 0, 0 }, 6767);
    self.listener.listen();

    self.epoll.init();
    if (!self.epoll.add(self.listener.socket, linux.EPOLL.IN)) {
        log.err(
            "init() failed: could not add listener socket to epoll interest list",
            .{},
        );
        std.process.exit(1);
    }

    self.clients = .empty;
    self.clients.appendNTimes(gpa, null, 4096) catch |err| {
        log.err(
            "init() failed, {}: could not allocate clients array list",
            .{err},
        );
        std.process.exit(1);
    };

    self.state = .initialized;
    log.info("event loop and event loop dependencies initialized", .{});
}

/// Deinitializes the `EventLoop` along with its dependencies *(e.g. `net.Listener`,
/// `net.Epoll`)*.
pub fn deinit(self: *EventLoop, gpa: Allocator) void {
    assert.cheap(self.state != .uninitialized);
    assert.cheap(self.state != .running);
    assert.cheap(self.state != .deinitialized);

    self.listener.deinit();
    self.epoll.deinit();
    for (self.clients.items) |c| {
        const client = c orelse continue;
        client.deinit(gpa);
        gpa.destroy(client);
    }
    self.clients.deinit(gpa);

    self.state = .deinitialized;
    log.info("event loop and event loop dependencies deinitialized", .{});
}

/// Starts the `EventLoop` instance's main event loop.
pub fn run(self: *EventLoop, gpa: Allocator) void {
    assert.cheap(self.state == .initialized);

    log.info("event loop running", .{});
    self.state = .running;
    while (true) {
        self.process_events(gpa);
    }
    self.state = .stopped;
}

/// Performs operations related to handling client connections and client
/// requests.
fn process_events(self: *EventLoop, gpa: Allocator) void {
    assert.cheap(self.state == .running);

    for (self.epoll.wait(-1)) |epoll_event| {
        const fd: i32 = epoll_event.data.fd;
        const events: u32 = epoll_event.events;

        if (fd == self.listener.socket and (events & linux.EPOLL.IN) != 0) {
            const connection_fd: i32 = self.listener.accept() orelse continue;
            self.accept_client(gpa, connection_fd);
            continue;
        }

        self.handle_client(gpa, fd, events);
    }
}

/// Performs the operations required to initialize, register, and store a `net.Client`
/// instance.
fn accept_client(self: *EventLoop, gpa: Allocator, connection_fd: i32) void {
    assert.cheap(self.state == .running);
    assert.cheap(connection_fd >= 0);

    const client_index: usize = @intCast(connection_fd);
    if (client_index >= self.clients.items.len) {
        const count: usize = client_index - self.clients.items.len + 1;
        self.clients.appendNTimes(gpa, null, count) catch |err| {
            log.err("grow clients memory failed, {}: fd={d}", .{ err, connection_fd });
            self.accept_client_rollback(gpa, connection_fd);
            return;
        };
    }

    const client: *net.Client = gpa.create(net.Client) catch |err| {
        log.err("client allocation failed, {}: fd={d}", .{ err, connection_fd });
        self.accept_client_rollback(gpa, connection_fd);
        return;
    };
    client.init(connection_fd);
    self.clients.items[client_index] = client;

    if (!self.epoll.add(connection_fd, linux.EPOLL.IN)) {
        self.accept_client_rollback(gpa, connection_fd);
    }
}

/// Rollbacks the operations performed in accept_client() when any client related
/// operations fails. The following are the rollback operations performed by this
/// function:
/// - Closes the connection fd if not client has been committed to memory.
/// - Cleans up memory related to client if `Epoll`.`add()` fails *(e.g. set client's
///   entry to null in `clients`, deinitialize `net.Client` instance, deallocate
///   memory allocations used to instantiate and store `net.Client`, etc.)*.
fn accept_client_rollback(self: *EventLoop, gpa: Allocator, client_fd: i32) void {
    const client_index: usize = @intCast(client_fd);

    assert.cheap(self.state == .running);
    assert.cheap(client_fd >= 0);
    assert.cheap(client_index < self.clients.items.len);

    // rollback on Epoll.add() failure
    if (self.clients.items[client_index]) |client| {
        self.clients.items[client_index] = null;
        client.deinit(gpa);
        gpa.destroy(client);
        return;
    }

    // rollback on allocation failures for net.Client
    sys.linux.close(client_fd) catch |e| switch (e) {
        error.Interrupted => {},
        error.Unexpected => {
            @panic("close() failed, unexpected error");
        },
    };

    assert.cheap(self.clients.items[client_index] == null);
}

/// Perform `net.Client` operations depending on the intent and readiness of a `net.
/// Client` instance.
fn handle_client(self: *EventLoop, gpa: Allocator, client_fd: i32, events: u32) void {
    assert.cheap(self.state == .running);
    assert.cheap(client_fd >= 0);

    const client_index: usize = @intCast(client_fd);
    const client: *net.Client = self.clients.items[client_index] orelse return;

    if ((events & linux.EPOLL.IN) != 0 and client.state_current == .receive) {
        client.receive_requests(gpa);
    }

    if ((events & linux.EPOLL.OUT) != 0 and client.state_current == .send) {
        client.send_responses();
    }

    const dead = (events & (linux.EPOLL.ERR | linux.EPOLL.HUP)) != 0;
    const closed = client.state_current == .close or client.state_desired == .close;
    if (dead or closed) {
        self.close_client(gpa, client.socket);
        return;
    }

    if (client.state_current == client.state_desired) return;

    switch (client.state_desired) {
        .receive => {
            self.epoll.modify(client.socket, linux.EPOLL.IN);
            client.state_current = .receive;
        },
        .send => {
            self.epoll.modify(client.socket, linux.EPOLL.OUT);
            client.state_current = .send;
        },
        .close => unreachable,
    }
}

/// Deinitializes a `net.Client` instance and cleans up any resources consumed through
/// out the lifetime of the instance.
fn close_client(self: *EventLoop, gpa: Allocator, client_fd: i32) void {
    assert.cheap(self.state == .running);
    assert.cheap(client_fd >= 0);

    const client_index: usize = @intCast(client_fd);
    const client: *net.Client = self.clients.items[client_index] orelse return;

    client.deinit(gpa);
    gpa.destroy(client);
    self.clients.items[client_index] = null;
}
