const std = @import("std");
const linux = std.os.linux;

/// Performs a blocking read on a socket's receive buffer and stores the bytes read in
/// the provided buffer.
pub const ReadResult = enum { ok, eof, failed };
pub fn read(fd: i32, buffer: []u8) ReadResult {
    var rest: []u8 = buffer;
    while (rest.len > 0) {
        const byteas_read_count: usize = linux.read(fd, rest.ptr, rest.len);
        switch (linux.errno(byteas_read_count)) {
            .SUCCESS => if (byteas_read_count == 0) return .eof,
            .INTR => continue,
            else => return .failed,
        }
        rest = rest[byteas_read_count..];
    }
    return .ok;
}

/// Performs a blocking write on a socket's send buffer using the bytes stored in the
/// provided buffer.
pub fn write(fd: i32, buffer: []u8) bool {
    var rest: []u8 = buffer;
    while (rest.len > 0) {
        const bytes_written_count: usize = linux.write(fd, rest.ptr, rest.len);
        switch (linux.errno(bytes_written_count)) {
            .SUCCESS => {},
            .INTR => continue,
            else => return false,
        }
        rest = rest[bytes_written_count..];
    }
    return true;
}
