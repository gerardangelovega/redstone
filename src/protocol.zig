const std = @import("std");

pub const header_length: u32 = 4;
pub const body_length_max: u32 = 64 * 1024; // 64 KB

pub const Commands = enum(u16) {
    invalid = 0,

    // 0001-0499: reserved connection commands
    ping = 1,
    echo = 2,
    hello = 3,
    quit = 4,

    // 0500-0599: reserved server/admin commands
    info = 500,

    // 1000+    : reserved for data commands
    // 200 opcodes are reserver for each data structure
    get = 1000,
    set = 1001,
    del = 1002,
};

pub const ArgsExpected = std.EnumMap(Commands, u32).init(.{
    .invalid = 0,

    .ping = 0,
    .echo = 1,
    .hello = 0,
    .quit = 0,

    .info = 0,

    .get = 1,
    .set = 1,
    .del = 1,
});
