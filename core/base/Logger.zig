const std = @import("std");
const core = @import("../core.zig");

const Self = @This();

platform: core.Platform.Logger,

pub fn init(self: *Self, ctx: *const core.Core) !void {
    self.platform = ctx.platform.logger;
}

pub fn log(
    self: *Self,
    level: std.log.Level,
    comptime format: []const u8,
    args: anytype,
) void {
    var buf: [256]u8 = undefined;
    const out = std.fmt.bufPrintZ(&buf, format, args) catch {
        return;
    };
    self.platform.vtable.log(self.platform.ptr, level, out);
}
pub fn info(
    self: *Self,
    comptime format: []const u8,
    args: anytype,
) void {
    self.log(.info, format, args);
}
pub fn err(
    self: *Self,
    comptime format: []const u8,
    args: anytype,
) void {
    self.log(.err, format, args);
}
