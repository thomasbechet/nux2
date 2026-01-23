const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

nodes: nux.NodePool(struct {
    position: nux.Vec3,
    pub fn init(_: *Self) !@This() {
        return .{ .position = .zero() };
    }
    pub fn deinit(_: *Self, _: *@This()) void {}
    pub fn save(self: *Self, writer: *nux.Writer, data: *@This()) !void {
        _ = data;
        _ = self;
        try writer.write(32);
    }
}),
node: *nux.Node,
logger: *nux.Logger,

pub fn new(self: *Self, parent: nux.NodeID) !nux.NodeID {
    return (try self.nodes.new(parent)).id;
}
pub fn getPosition(self: *Self, id: nux.NodeID) !nux.Vec3 {
    return (try self.nodes.get(id)).position;
}
pub fn setPosition(self: *Self, id: nux.NodeID, position: nux.Vec3) !void {
    (try self.nodes.get(id)).position = position;
}
