const std = @import("std");

pub const server = std.log.scoped(.server);
pub const client = std.log.scoped(.client);
