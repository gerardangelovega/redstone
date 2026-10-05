const std = @import("std");
const linux = std.os.linux;

const net = @import("net.zig");

const EventLoop = @This();

listener: net.Listener,
epoll: net.Epoll,
clients: std.ArrayList(?*net.Client),

pub fn init(self: *EventLoop, gpa: std.mem.Allocator) void {
    self.* = .{
        .listener = undefined,
        .epoll = undefined,
        .clients = undefined,
    };

    self.listener.init();
    self.listener.bind([4]u8{ 0, 0, 0, 0 }, 6767);
    self.listener.listen();

    self.epoll.init();
    if (!self.epoll.add(self.listener.socket, linux.EPOLL.IN)) {
        std.log.err(
            "init() failed: could not add listener socket to epoll interest list",
            .{},
        );
        std.process.exit(1);
    }

    self.clients = .empty;
    self.clients.appendNTimes(gpa, null, 4096) catch |err| {
        std.log.err(
            "init() failed: error={}, could not allocate clients array list",
            .{err},
        );
    };
}

pub fn deinit(self: *EventLoop, gpa: std.mem.Allocator) void {
    for (self.clients.items) |c| {
        const client = c orelse continue;
        client.deinit(gpa);
    }
    self.clients.deinit(gpa);
    self.listener.deinit();
    self.epoll.deinit();
}

pub fn run(self: *EventLoop, gpa: std.mem.Allocator) void {
    while (true) {
        self.process_events(gpa);
    }
}

fn process_events(self: *EventLoop, gpa: std.mem.Allocator) void {
    for (self.epoll.wait(-1)) |event| {
        const fd: i32 = event.data.fd;
        const ev: u32 = event.events;

        if (fd == self.listener.socket and (ev & linux.EPOLL.IN) != 0) {
            const client_fd: i32 = self.listener.accept() orelse continue;
            self.accept_client(gpa, client_fd);
            continue;
        }

        self.handle_client(gpa, fd, ev);
    }
}

fn accept_client(self: *EventLoop, gpa: std.mem.Allocator, fd: i32) void {
    const idx: usize = @intCast(fd);
    if (idx >= self.clients.items.len) {
        const count: usize = idx - self.clients.items.len + 1;
        self.clients.appendNTimes(gpa, null, count) catch |err| {
            std.log.err("grow clients memory failed: fd={d}, error={}", .{ fd, err });
            net.common.fd_close(fd);
            return;
        };
    }

    const client: *net.Client = gpa.create(net.Client) catch |err| {
        std.log.err("client alloc failed: fd={d}, error={}", .{ fd, err });
        net.common.fd_close(fd);
        return;
    };
    client.init(fd);

    if (!self.epoll.add(fd, linux.EPOLL.IN)) {
        client.deinit(gpa);
        gpa.destroy(client);
        return;
    }

    self.clients.items[idx] = client;
}

fn handle_client(self: *EventLoop, gpa: std.mem.Allocator, fd: i32, events: u32) void {
    const idx: usize = @intCast(fd);
    const client: *net.Client = self.clients.items[idx] orelse return;

    if ((events & linux.EPOLL.IN) != 0) {
        client.read(gpa);
    }

    if ((events & linux.EPOLL.OUT) != 0) {
        client.write();
    }

    const dead = (events & (linux.EPOLL.ERR | linux.EPOLL.HUP)) != 0;
    const closed = client.state_current == .close or client.state_desired == .close;

    if (dead or closed) {
        self.close_client(gpa, client.socket);
        return;
    }

    if (client.state_current == client.state_desired) {
        return;
    }

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

fn close_client(self: *EventLoop, gpa: std.mem.Allocator, fd: i32) void {
    const idx: usize = @intCast(fd);
    const client: *net.Client = self.clients.items[idx] orelse return;

    client.deinit(gpa);
    gpa.destroy(client);
    self.clients.items[idx] = null;
}

// listener,
// epoll instance,
// clients,
// init()
// deinit()
// run()
// process_events()
// process_timers()
