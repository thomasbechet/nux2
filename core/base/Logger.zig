const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

initialized: bool = false,
platform: nux.Platform.Logger,

pub fn init(self: *Self, ctx: *const nux.Core) !void {
    self.platform = ctx.platform.logger;
    self.initialized = true;
}

pub fn log(
    self: *Self,
    level: std.log.Level,
    comptime format: []const u8,
    args: anytype,
) void {
    if (self.initialized) {
        var buf: [256]u8 = undefined;
        const out = std.fmt.bufPrintZ(&buf, format, args) catch {
            return;
        };
        self.platform.vtable.log(self.platform.ptr, level, out);
    }
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
