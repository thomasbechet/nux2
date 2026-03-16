const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

allocator: std.mem.Allocator,
texture: *nux.Texture,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;

    var cmds = nux.Renderer.CommandBuffer {};
}

pub fn render(self: *Self, cmds: nux.Renderer.CommandBuffer) !void {
    for (cmds.commands.items) |cmd| {
        _ = cmd;
        _ = self;
    }
}
