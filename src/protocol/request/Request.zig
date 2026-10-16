const std = @import("std");

const Request = @This();

const message = @import("../message.zig");

header: Header,
body: Body,

pub const Header = extern struct {
    pub const size: u32 = 8;

    message_size: u32,
    command_code: u16,
    data_count: u16,
};

pub const Body = struct {
    data: []const message.Datum,
    size: u32,
};

pub fn init(self: *Request, command_code: u16, data: []const message.Datum) void {
    self.body.data = data;
    self.body.size = 0;
    for (self.body.data) |datum| {
        self.body.size = self.body.size + datum.size();
    }

    self.header.message_size = Header.size + self.body.size;
    self.header.command_code = command_code;
    self.header.data_count = @intCast(self.body.data.len);
}

pub fn validate(_: *const Request) bool {}
