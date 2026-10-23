const std = @import("std");

const net = @import("net.zig");

const log = std.log;

const Store = @This();

clients: std.ArrayList(?*net.Client),
data: std.StringHashMap([]const u8),

pub fn init(self: *Store, allocator: std.mem.Allocator) void {
    // SAFETY: defined within the function
    self.* = .{
        .clients = undefined,
        .data = undefined,
    };

    self.clients = .empty;
    self.clients.appendNTimes(allocator, null, 4096) catch |err| {
        log.err("init() failed, {}: could not allocate clients array list", .{err});
        std.process.exit(1);
    };

    self.data = .init(allocator);
    self.data.ensureTotalCapacity(4096) catch |err| {
        log.err("init() failed, {}: could not reserve adequate hashmap capacity", .{err});
        std.process.exit(1);
    };
}

pub fn deinit(self: *Store, allocator: std.mem.Allocator) void {
    self.clients.deinit(allocator);
    self.data.deinit();
}
