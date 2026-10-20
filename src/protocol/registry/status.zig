pub const Status = enum(u16) {
    ok = 1,
    err = 2,

    pub fn encode(self: *const Status) u16 {
        return @intFromEnum(self.*);
    }

    pub fn decode(code: u16) Status {
        return @enumFromInt(code);
    }
};
