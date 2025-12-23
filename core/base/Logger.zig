const std = @import("std");

const Self = @This();

pub fn info(
    self: *Self,
    comptime format: []const u8,
    args: anytype,
) void {
    _ = self;
    std.log.info(format, args);
}
