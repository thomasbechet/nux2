const std = @import("std");
const nux = @import("../nux.zig");

const Module = @This();
const Node = struct {
    data: ?[]u8 = null,
    size: nux.Vec2 = .zero(),
    path: ?[]const u8 = null,
    pub fn init(_: *Module) !@This() {
        return .{};
    }
};

nodes: nux.NodePool(Node),
node: *nux.Node,
logger: *nux.Logger,
disk: *nux.Disk,
allocator: std.mem.Allocator,

pub fn init(self: *Module, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
