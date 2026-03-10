const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

config: *nux.Config,
platform: nux.Platform.Window,
width: u32,
height: u32,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.platform = core.platform.window;
    self.width = try self.config.getInt(u32, "Window.width");
    self.height = try self.config.getInt(u32, "Window.height");
    try self.platform.vtable.open(self.platform.ptr, self.width, self.height);
}
pub fn deinit(self: *Self) void {
    self.platform.vtable.close(self.platform.ptr);
}
pub fn onEvent(self: *Self, event: *const nux.Platform.Event) void {
    switch (event.*) {
        .windowResized => |data| {
            self.width = data.width;
            self.height = data.height;
        },
        else => {},
    }
}

pub fn resize(self: *Self, w: u32, h: u32) void {
    self.platform.vtable.resize(self.platform.ptr, w, h);
}
