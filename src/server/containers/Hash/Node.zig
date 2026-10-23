const std = @import("std");

const SipHash64 = std.crypto.auth.siphash.SipHash64(1, 3);

const Node = @This();

hash: u64,
next: ?*Node,

pub fn init(self: *Node, key: []const u8) void {
    self.hash = fnv_hash(key);
    self.next = null;
}

fn fnv_hash(data: []const u8) u64 {
    var h: u32 = 0x811c9dc5;
    for (0..data.len) |i| {
        h = (h +% data[i]) *% 0x01000193;
    }
    return h;
}
