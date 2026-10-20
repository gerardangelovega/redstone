const std = @import("std");

pub const Datum = @import("message/datum.zig").Datum;
pub const Request = @import("message/Request.zig");
pub const Response = @import("message/Response.zig");

pub const data_max_count: u32 = std.math.maxInt(u16);
pub const bytes_max: u32 = 4 * 1024 * 1024;
