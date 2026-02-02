const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Node = struct {
    texture: nux.NodeID = .null,
    mesh: nux.NodeID = .null,
    transform: nux.NodeID = .null,
};

nodes: nux.NodePool(Node),
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn setMesh(self: *Self, id: nux.NodeID, mesh: nux.NodeID) !void {
    (try self.nodes.get(id)).mesh = mesh;
}
pub fn getMesh(self: *Self, id: nux.NodeID) !nux.NodeID {
    return (try self.nodes.get(id)).mesh;
}
pub fn setTexture(self: *Self, id: nux.NodeID, texture: nux.NodeID) !void {
    (try self.nodes.get(id)).texture = texture;
}
pub fn getTexture(self: *Self, id: nux.NodeID) !nux.NodeID {
    return (try self.nodes.get(id)).texture;
}
pub fn setTransform(self: *Self, id: nux.NodeID, transform: nux.NodeID) !void {
    (try self.nodes.get(id)).transform = transform;
}
pub fn getTransform(self: *Self, id: nux.NodeID) !nux.NodeID {
    return (try self.nodes.get(id)).transform;
}
