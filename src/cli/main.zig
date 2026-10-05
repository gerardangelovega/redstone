const std = @import("std");
const linux = std.os.linux;
const shared = @import("shared");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var rv: usize = 0;

    const fd: i32 = @intCast(
        linux.socket(
            linux.AF.INET,
            linux.SOCK.STREAM,
            linux.IPPROTO.TCP,
        ),
    );
    switch (linux.errno(rv)) {
        .SUCCESS => {},
        else => |errno| {
            std.log.err(
                "socket() failed: {s}",
                .{@tagName(errno)},
            );
            return error.SocketFailed;
        },
    }
    defer _ = linux.close(fd);

    const address: linux.sockaddr.in = .{
        .family = linux.AF.INET,
        .port = std.mem.nativeTo(u16, 6767, .big),
        .addr = @bitCast([4]u8{ 127, 0, 0, 1 }),
    };
    rv = linux.connect(fd, @ptrCast(&address), @sizeOf(linux.sockaddr.in));
    switch (linux.errno(rv)) {
        .SUCCESS => {},
        else => |errno| {
            std.log.err(
                "connect() failed: {s}",
                .{@tagName(errno)},
            );
            return error.ConnectFailed;
        },
    }

    if (!send_request(fd, gpa, "hello once")) return;
    if (!send_request(fd, gpa, "hello twice")) return;
    if (!send_request(fd, gpa, "hello thrice")) return;

    if (!receive_response(fd, gpa)) return;
    if (!receive_response(fd, gpa)) return;
    if (!receive_response(fd, gpa)) return;
}

fn send_request(fd: i32, gpa: std.mem.Allocator, body: []const u8) bool {
    const io = shared.io;
    const message = shared.protocol.message;

    if (body.len > message.body_length_max) {
        return false;
    }

    var header: [message.header_length]u8 = undefined;
    std.mem.writeInt(u32, &header, @intCast(body.len), .little);

    var outgoing: std.ArrayList(u8) = .empty;
    defer outgoing.deinit(gpa);
    outgoing.ensureUnusedCapacity(gpa, message.header_length + body.len) catch |err| {
        std.log.err(
            "reserving outgoing memory for message failed: fd={d} error={}",
            .{ fd, err },
        );
        return false;
    };
    outgoing.appendSliceAssumeCapacity(&header);
    outgoing.appendSliceAssumeCapacity(body);

    return io.blocking.write(fd, outgoing.items);
}

fn receive_response(fd: i32, gpa: std.mem.Allocator) bool {
    const io = shared.io;
    const message = shared.protocol.message;

    var incoming: std.ArrayList(u8) = .empty;
    defer incoming.deinit(gpa);
    incoming.appendNTimes(gpa, 0, message.header_length) catch |err| {
        std.log.err(
            "reserving incoming memory for header failed: fd={d} error={}",
            .{ fd, err },
        );
        return false;
    };
    switch (io.blocking.read(fd, incoming.items[0..message.header_length])) {
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

    const header = incoming.items[0..message.header_length];
    const body_length: u32 = std.mem.readInt(u32, header, .little);
    if (body_length > message.body_length_max) {
        return false;
    }

    const message_length = message.header_length + body_length;
    incoming.appendNTimes(gpa, 0, body_length) catch |err| {
        std.log.err(
            "reserving incoming memory for body failed: fd={d} error={}",
            .{ fd, err },
        );
        return false;
    };
    switch (io.blocking.read(fd, incoming.items[message.header_length..message_length])) {
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

    std.log.info("Server: {s}", .{incoming.items[message.header_length..message_length]});

    return true;
}
