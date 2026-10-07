// standard library, library, and module imports
const std = @import("std");
const protocol = @import("protocol");
const sys = @import("sys");

// files
const io = @import("io.zig");

// aliases
const Allocator = std.mem.Allocator;
const linux = std.os.linux;
const log = std.log;

// TODO2: extract and abstract connection and request-response logic into struct

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var rv: usize = 0;

    const fd: i32 = sys.linux.socket(
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

    defer sys.linux.close(fd) catch |err| switch (err) {
        error.Interrupted => {},
        error.Unexpected => {
            @panic("close() failed, unexpected error");
        },
    };

    // TODO2: refactor implementation using connect() syscall wrapper
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

fn send_request(fd: i32, gpa: Allocator, body: []const u8) bool {
    if (body.len > protocol.body_length_max) {
        return false;
    }

    var header: [protocol.header_length_fixed]u8 = undefined;
    std.mem.writeInt(u32, &header, @intCast(body.len), .little);

    var outgoing: std.ArrayList(u8) = .empty;
    defer outgoing.deinit(gpa);
    outgoing.ensureUnusedCapacity(gpa, protocol.header_length_fixed + body.len) catch |err| {
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

fn receive_response(fd: i32, gpa: Allocator) bool {
    var incoming: std.ArrayList(u8) = .empty;
    defer incoming.deinit(gpa);
    incoming.appendNTimes(gpa, 0, protocol.header_length_fixed) catch |err| {
        std.log.err(
            "reserving incoming memory for header failed: fd={d} error={}",
            .{ fd, err },
        );
        return false;
    };
    switch (io.blocking.read(fd, incoming.items[0..protocol.header_length_fixed])) {
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

    const header = incoming.items[0..protocol.header_length_fixed];
    const body_length: u32 = std.mem.readInt(u32, header, .little);
    if (body_length > protocol.body_length_max) {
        return false;
    }

    const message_length = protocol.header_length_fixed + body_length;
    incoming.appendNTimes(gpa, 0, body_length) catch |err| {
        std.log.err(
            "reserving incoming memory for body failed: fd={d} error={}",
            .{ fd, err },
        );
        return false;
    };
    switch (io.blocking.read(fd, incoming.items[protocol.header_length_fixed..message_length])) {
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

    std.log.info("Server: {s}", .{incoming.items[protocol.header_length_fixed..message_length]});

    return true;
}
