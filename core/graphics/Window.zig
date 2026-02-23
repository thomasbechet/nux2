const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

config: *nux.Config,
platform: nux.Platform.Window,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.platform = core.platform.window;
    const w = try self.config.getInt(u32, "Window.width");
    const h = try self.config.getInt(u32, "Window.height");
    try self.platform.vtable.open(self.platform.ptr, w, h);
}
pub fn deinit(self: *Self) void {
    self.platform.vtable.close(self.platform.ptr);
}
pub fn resize(self: *Self, w: u32, h: u32) void {
    self.platform.vtable.resize(self.platform.ptr, w, h);
}
