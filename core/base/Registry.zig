const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .allocator = allocator,
    };
}
