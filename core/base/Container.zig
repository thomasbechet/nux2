const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub fn init(self: *Self, core: *const nux.Core) !void {
    _ = self;
    _ = core;
}
pub fn deinit(self: *Self) void {
    _ = self;
}
