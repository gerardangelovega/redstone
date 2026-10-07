// standard library, library, and module imports
const std = @import("std");
const sys = @import("sys");

// file imports
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
epoll: net.Epoll,
clients: std.ArrayList(?*net.Client), // array map mapping fd as index to a net.Client
state: State,

/// Initializes the `EventLoop` along with its dependencies *(e.g. `net.Listener`,
/// `net.Epoll`, etc.)* and sets `EventLoop`.`state` to `initialized`.
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
/// `net.Epoll`)* and sets `EventLoop`.`state` to `initialized`.
pub fn deinit(self: *EventLoop, gpa: Allocator) void {
    std.debug.assert(self.state != .uninitialized);
    std.debug.assert(self.state != .running);
    std.debug.assert(self.state != .deinitialized);

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

/// Starts the server's main event loop. Sets `EventLoop`.`state` to `running` while
/// the main event loop is running and sets it to `stopped` when the main event loop
/// stops.
pub fn run(self: *EventLoop, gpa: Allocator) void {
    std.debug.assert(self.state == .initialized);

    log.info("event loop running", .{});
    self.state = .running;
    while (true) {
        self.process_events(gpa);
    }
    self.state = .stopped;
}

/// Executes operations and methods related to handling client connections and client
/// requests.
fn process_events(self: *EventLoop, gpa: Allocator) void {
    std.debug.assert(self.state == .running);

    for (self.epoll.wait(-1)) |epoll_event| {
        const fd: i32 = epoll_event.data.fd;
        const events: u32 = epoll_event.events;

        if (fd == self.listener.socket and (events & linux.EPOLL.IN) != 0) {
            const client_fd: i32 = self.listener.accept() orelse continue;
            self.accept_client(gpa, client_fd);
            continue;
        }

        self.handle_client(gpa, fd, events);
    }
}

/// Performs the operations required to initialize, register, and store a `net.Client`
/// instance.
fn accept_client(self: *EventLoop, gpa: Allocator, fd: i32) void {
    std.debug.assert(self.state == .running);
    std.debug.assert(fd >= 0);

    const client_index: usize = @intCast(fd);
    if (client_index >= self.clients.items.len) {
        const count: usize = client_index - self.clients.items.len + 1;
        self.clients.appendNTimes(gpa, null, count) catch |err| {
            log.err("grow clients memory failed, {}: fd={d}", .{ err, fd });
            sys.linux.close(fd) catch |e| switch (e) {
                error.Interrupted => {},
                error.Unexpected => {
                    @panic("close() failed, unexpected error");
                },
            };
            return;
        };
    }

    const client: *net.Client = gpa.create(net.Client) catch |err| {
        log.err("client allocation failed, {}: fd={d}", .{ err, fd });
        sys.linux.close(fd) catch |e| switch (e) {
            error.Interrupted => {},
            error.Unexpected => {
                @panic("close() failed, unexpected error");
            },
        };
        return;
    };
    client.init(fd);

    if (!self.epoll.add(fd, linux.EPOLL.IN)) {
        client.deinit(gpa);
        gpa.destroy(client);
        return;
    }

    self.clients.items[client_index] = client;
}

/// Calls the `net.Client` instance's methods depending on the `net.Client` instance's
/// intent and readiness of connection resources.
fn handle_client(self: *EventLoop, gpa: Allocator, fd: i32, events: u32) void {
    std.debug.assert(self.state == .running);
    std.debug.assert(fd >= 0);

    const client_index: usize = @intCast(fd);
    const client: *net.Client = self.clients.items[client_index] orelse return;

    if ((events & linux.EPOLL.IN) != 0 and client.state_current == .read) {
        client.read(gpa);
    }

    if ((events & linux.EPOLL.OUT) != 0 and client.state_current == .write) {
        client.write();
    }

    const dead = (events & (linux.EPOLL.ERR | linux.EPOLL.HUP)) != 0;
    const closed = client.state_current == .close or client.state_desired == .close;
    if (dead or closed) {
        self.close_client(gpa, client.socket);
        return;
    }

    if (client.state_current == client.state_desired) return;

    switch (client.state_desired) {
        .read => {
            self.epoll.modify(client.socket, linux.EPOLL.IN);
            client.state_current = .read;
        },
        .write => {
            self.epoll.modify(client.socket, linux.EPOLL.OUT);
            client.state_current = .write;
        },
        .close => unreachable,
    }
}

/// Calls the `net.Client` instance's deinitializer and cleans up any allocation and
/// data structure associated with the `net.Client` instance.
fn close_client(self: *EventLoop, gpa: Allocator, fd: i32) void {
    std.debug.assert(self.state == .running);
    std.debug.assert(fd >= 0);

    const client_index: usize = @intCast(fd);
    const client: *net.Client = self.clients.items[client_index] orelse return;

    client.deinit(gpa);
    gpa.destroy(client);
    self.clients.items[client_index] = null;
}

// TODO2: implement shed_client() (multi stage clean up process for shedded clients)
