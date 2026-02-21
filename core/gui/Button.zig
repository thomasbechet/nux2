const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

const Node = struct {
    position: nux.Vec2,
    onClick: nux.ID,
};

nodes: nux.NodePool(Node),
signal: *nux.Signal,

pub fn click(self: *Self, id: nux.ID) !void {
    const node = try self.nodes.get(id); 
    try self.signal.emit(node.onClick, node); 
}
