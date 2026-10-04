const std = @import("std");
const linux = std.os.linux;

pub const ReadResult = enum { ok, eof, failed };
pub fn read(fd: i32, buffer: []u8) ReadResult {
    var rest: []u8 = buffer;
    while (rest.len > 0) {
        const rv: usize = linux.read(fd, rest.ptr, rest.len);
        switch (linux.errno(rv)) {
            .SUCCESS => if (rv == 0) return .eof,
            .INTR => continue,
            else => return .failed,
        }
        rest = rest[rv..];
    }
    return .ok;
}

pub fn write(fd: i32, buffer: []u8) bool {
    var rest: []u8 = buffer;
    while (rest.len > 0) {
        const rv: usize = linux.write(fd, rest.ptr, rest.len);
        switch (linux.errno(rv)) {
            .SUCCESS => {},
            .INTR => continue,
            else => return false,
        }
        rest = rest[rv..];
    }
    return true;
}
