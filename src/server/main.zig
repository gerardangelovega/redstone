const std = @import("std");
const linux = std.os.linux;
const shared = @import("shared");

const net = @import("net.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var epoll: net.Epoll = undefined;
    epoll.init();
    defer epoll.deinit();

    var server: net.Server = undefined;
    server.init();
    defer server.deinit();

    server.bind([4]u8{ 0, 0, 0, 0 }, 6767);
    server.listen();

    if (!epoll.add(server.socket, linux.EPOLL.IN)) {
        std.process.exit(1);
    }

    var fd2conn: std.ArrayList(?*net.Client) = .empty;
    try fd2conn.appendNTimes(gpa, null, 1024);
    defer fd2conn.deinit(gpa);

    while (true) {
        const events: []const linux.epoll_event = epoll.wait(-1);
        for (events) |ev| {
            const fd: i32 = ev.data.fd;
            const ee = ev.events;

            if (fd == server.socket and (ee & linux.EPOLL.IN) != 0) {
                const client_fd = server.accept() orelse continue;
                const idx: usize = @intCast(client_fd);
                if (idx >= fd2conn.items.len) {
                    const count = idx - fd2conn.items.len + 1;
                    fd2conn.appendNTimes(gpa, null, count) catch {
                        std.log.err("fd2conn grow failed: fd={d}", .{client_fd});
                        net.common.fd_close(client_fd);
                        continue;
                    };
                }

                const client: *net.Client = gpa.create(net.Client) catch {
                    std.log.err("client alloc failed: fd={d}", .{client_fd});
                    net.common.fd_close(client_fd);
                    continue;
                };
                client.init(client_fd);

                if (!epoll.add(client_fd, linux.EPOLL.IN)) {
                    client.deinit(gpa);
                    gpa.destroy(client);
                    continue;
                }

                fd2conn.items[idx] = client;
                continue;
            }

            const idx: usize = @intCast(fd);
            const client: *net.Client = fd2conn.items[idx] orelse continue;

            if ((ev.events & linux.EPOLL.IN) != 0) {
                client.read(gpa);
            }

            if ((ev.events & linux.EPOLL.OUT) != 0) {
                client.write();
            }

            const dead = (ev.events & (linux.EPOLL.ERR | linux.EPOLL.HUP)) != 0;
            const closed = client.state_current == .close or client.state_desired == .close;
            if (dead or closed) {
                client.deinit(gpa);
                gpa.destroy(client);
                fd2conn.items[idx] = null;
                continue;
            }

            if (client.state_current == client.state_desired) {
                continue;
            }

            switch (client.state_desired) {
                .read => {
                    epoll.modify(client.socket, linux.EPOLL.IN);
                    client.state_current = .read;
                },
                .write => {
                    epoll.modify(client.socket, linux.EPOLL.OUT);
                    client.state_current = .write;
                },
                .close => unreachable,
            }
        }
    }
}

fn process_request(client: *net.Client) bool {
    var read_buffer: [4 + 4096]u8 = undefined;
    switch (shared.io.blocking.read(client.socket, read_buffer[0..4])) {
        .ok => {},
        .eof => {
            std.log.debug("client disconnected: res=eof", .{});
            return false;
        },
        .failed => {
            std.log.warn("read_full() failed: res=failed", .{});
            return false;
        },
    }

    const len: u32 = std.mem.readInt(u32, read_buffer[0..4], .little);
    if (len > 4096) {
        std.log.warn("message is too long: len={d}", .{len});
        return false;
    }

    const total = len + 4;
    switch (shared.io.blocking.read(client.socket, read_buffer[4..total])) {
        .ok => {},
        .eof => {
            std.log.debug("client disconnected: res=eof", .{});
            return false;
        },
        .failed => {
            std.log.warn("read_full() failed: res=failed", .{});
            return false;
        },
    }

    std.log.info("Client: {s}", .{read_buffer[4 .. len + 4]});

    const response = "world";
    var write_buffer: [4 + response.len]u8 = undefined;
    std.mem.writeInt(u32, write_buffer[0..4], response.len, .little);
    @memcpy(write_buffer[4..], response);

    return shared.io.blocking.write(client.socket, &write_buffer);
}
