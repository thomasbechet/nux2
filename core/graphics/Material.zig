const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

components: nux.Components(struct {
    data: ?[]u8 = null,
    size: nux.Vec2 = .zero(),
    path: ?[]const u8 = null,
}),
node: *nux.Node,
logger: *nux.Logger,
file: *nux.File,
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
