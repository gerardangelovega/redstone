const std = @import("std");

pub fn root() void {
    std.debug.print("Hello, from shared!\n", .{});
}
