const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

nodes: nux.NodePool(struct {
    position: nux.Vec3,
}),
node: *nux.Node,
logger: *nux.Logger,

pub fn new(self: *Self, parent: nux.NodeID) !nux.NodeID {
    return self.nodes.add(parent, .{ .position = .zero() });
}
pub fn delete(self: *Self, id: nux.NodeID) !void {
    try self.nodes.remove(id);
}
pub fn getPosition(self: *Self, id: nux.NodeID) !nux.Vec3 {
    return (try self.nodes.get(id)).position;
}
