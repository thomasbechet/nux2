const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

config: *nux.Config,
platform: nux.Platform.Window,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.platform = core.platform.window;
    const w = self.config.sections.window.width;
    const h = self.config.sections.window.height;
    try self.platform.vtable.open(self.platform.ptr, w, h);
}
pub fn deinit(self: *Self) void {
    self.platform.vtable.close(self.platform.ptr);
}
pub fn resize(self: *Self, w: u32, h: u32) void {
    self.platform.vtable.resize(self.platform.ptr, w, h);
}
