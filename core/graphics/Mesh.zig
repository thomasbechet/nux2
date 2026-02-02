const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Node = struct {};

nodes: nux.NodePool(Node),
node: *nux.Node,
logger: *nux.Logger,
disk: *nux.Disk,
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
