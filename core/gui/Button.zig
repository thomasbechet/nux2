const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

const Node = struct {
    transform: nux.ID = .null,
    onClick: nux.ID = .null,
};

node: *nux.Node,
nodes: nux.NodePool(Node),
signal: *nux.Signal,

pub fn new(self: *Self, parent: nux.ID) !nux.ID {
    return try self.nodes.new(parent, .{});
}
pub fn click(self: *Self, id: nux.ID) !void {
    const node = try self.nodes.get(id);
    try self.signal.emit(node.onClick, id);
}
