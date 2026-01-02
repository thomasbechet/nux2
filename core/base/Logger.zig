const std = @import("std");
const core = @import("../core.zig");

const Self = @This();

platform: core.Platform.Logger,

pub fn init(self: *Self, ctx: *const core.Core) !void {
    self.platform = ctx.platform.logger;
}

pub fn info(
    self: *Self,
    comptime format: []const u8,
    args: anytype,
) void {
    _ = format;
    _ = args;
    self.platform.vtable.log(self.platform.ptr, .info, "test");
}

pub fn err(
    self: *Self,
    comptime format: []const u8,
    args: anytype,
) void {
    _ = format;
    _ = args;
    self.platform.vtable.log(self.platform.ptr, .err, "test");
}
