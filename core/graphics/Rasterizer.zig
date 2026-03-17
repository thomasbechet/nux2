const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

allocator: std.mem.Allocator,
texture: *nux.Texture,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn render(self: *Self, cmds: nux.Graphics.CommandBuffer) !void {
    _ = self;
    _ = cmds;
}
