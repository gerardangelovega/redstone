// standard library, library, and module imports
const std = @import("std");
const sys = @import("sys");

// file imports
const Store = @import("Store.zig");
const assert = @import("assert");
const net = @import("net.zig");
const protocol = @import("protocol");
const exectuors = @import("executors.zig");

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
// clients: std.ArrayList(?*net.Client), // array map mapping fd as index to a net.Client
store: Store,
state: State,

/// Initializes an existing `EventLoop` instances along with its dependencies
/// *(e.g. `net.Listener`, `net.Epoll`, etc.)*.
pub fn init(self: *EventLoop, gpa: Allocator) void {
    // SAFETY: defined within the function
    self.* = .{
        .listener = undefined,
        .epoll = undefined,
        .store = undefined,
        .state = .uninitialized,
    };

    self.listener.init();
    self.listener.bind([4]u8{ 0, 0, 0, 0 }, 6767);
    self.listener.listen();

    self.epoll.init();
    if (!self.epoll.add(self.listener.socket, linux.EPOLL.IN)) {
        log.err("init() failed: could not add listener socket to epoll interest list", .{});
        std.process.exit(1);
    }

    // self.clients = .empty;
    // self.clients.appendNTimes(gpa, null, 4096) catch |err| {
    //     log.err("init() failed, {}: could not allocate clients array list", .{err});
    //     std.process.exit(1);
    // };
    self.store.init(gpa);

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
    for (self.store.clients.items) |c| {
        const client = c orelse continue;
        client.deinit(gpa);
        gpa.destroy(client);
    }
    self.store.clients.deinit(gpa);

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
    if (client_index >= self.store.clients.items.len) {
        const count: usize = client_index - self.store.clients.items.len + 1;
        self.store.clients.appendNTimes(gpa, null, count) catch |err| {
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
    self.store.clients.items[client_index] = client;

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
    assert.cheap(client_index < self.store.clients.items.len);

    // rollback on Epoll.add() failure
    if (self.store.clients.items[client_index]) |client| {
        self.store.clients.items[client_index] = null;
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

    assert.cheap(self.store.clients.items[client_index] == null);
}

/// Perform `net.Client` operations depending on the intent and readiness of a `net.
/// Client` instance.
fn handle_client(self: *EventLoop, gpa: Allocator, client_fd: i32, events: u32) void {
    assert.cheap(self.state == .running);
    assert.cheap(client_fd >= 0);

    const client_index: usize = @intCast(client_fd);
    const client: *net.Client = self.store.clients.items[client_index] orelse return;

    if ((events & linux.EPOLL.IN) != 0 and client.state_current == .receive) {
        self.handle_client_receive(gpa, client);
    }

    if ((events & linux.EPOLL.OUT) != 0 and client.state_current == .send) {
        self.handle_client_send(client);
    }

    const dead = (events & (linux.EPOLL.ERR | linux.EPOLL.HUP)) != 0;
    const closed = client.state_current == .close or client.state_desired == .close;
    if (dead or closed) {
        self.handle_client_close(gpa, client.socket);
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

fn handle_client_receive(self: *EventLoop, gpa: Allocator, client: *net.Client) void {
    assert.cheap(self.state == .running);

    // Peek/View Received Bytes
    const received = client.receive_requests(gpa);

    while (received) {
        const received_bytes: []const u8 = client.peek_received_bytes();

        // Request Parsing
        // SAFETY: initialized by parse();
        var request: protocol.message.Request = undefined;
        const request_parse_result = request.parse(gpa, received_bytes) catch |err| {
            log.debug("request parsing allocations failed, {}", .{err});
            client.state_desired = .close;
            break;
        };

        // Request Validation
        switch (request_parse_result) {
            .incomplete => {
                break;
            },
            .malformed => {
                client.state_desired = .close;
                request.deinit(gpa);
                break;
            },
            .complete => {},
        }
        defer request.deinit(gpa);

        // Command Dispatching & Execution and Response Generation
        // SAFETY: defined in the following if-statement
        var response: protocol.message.Response = undefined;
        const command: protocol.registry.Command = .decode(request.header.command_code);
        if (!exectuors.dispatch(gpa, &self.store, command, &request, &response)) {
            client.state_desired = .close;
            break;
        }
        defer response.deinit(gpa);

        // Response Serialization
        const response_bytes = gpa.alloc(u8, response.header.message_size) catch |err| {
            log.debug("response serliazing allocations failed, {}", .{err});
            client.state_desired = .close;
            break;
        };
        response.serialize(response_bytes);

        // Response Writing into Send Buffer
        if (!client.append_send_bytes(gpa, response_bytes)) {
            client.state_desired = .close;
            break;
        }

        // Consume Received Bytes used in Request-Response
        client.consume_received_bytes(request.header.message_size);
    }

    if (client.buffer_send.items.len > 0) {
        client.state_current = .send;
        client.state_desired = .send;
        client.send_responses();
    } else {
        if (client.state_desired != .close and client.state_current != .close) {
            client.state_desired = .send;
        }
    }
}

fn handle_client_send(self: *const EventLoop, client: *net.Client) void {
    assert.cheap(self.state == .running);

    client.send_responses();
}

/// Deinitializes a `net.Client` instance and cleans up any resources consumed through
/// out the lifetime of the instance.
fn handle_client_close(self: *EventLoop, gpa: Allocator, client_fd: i32) void {
    assert.cheap(self.state == .running);
    assert.cheap(client_fd >= 0);

    const client_index: usize = @intCast(client_fd);
    const client: *net.Client = self.store.clients.items[client_index] orelse return;

    client.deinit(gpa);
    gpa.destroy(client);
    self.store.clients.items[client_index] = null;
}
