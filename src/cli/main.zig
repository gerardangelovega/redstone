const std = @import("std");
const shared = @import("shared");

pub fn main(_: std.process.Init) !void {
    std.debug.print("Hello, from cli!\n", .{});
    shared.root();
}
