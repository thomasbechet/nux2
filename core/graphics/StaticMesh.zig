const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Node = struct {
    texture: nux.ID = .null,
    mesh: nux.ID = .null,
    transform: nux.ID = .null,
};

nodes: nux.NodePool(Node),
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn setMesh(self: *Self, id: nux.ID, mesh: nux.ID) !void {
    (try self.nodes.get(id)).mesh = mesh;
}
pub fn getMesh(self: *Self, id: nux.ID) !nux.ID {
    return (try self.nodes.get(id)).mesh;
}
pub fn setTexture(self: *Self, id: nux.ID, texture: nux.ID) !void {
    (try self.nodes.get(id)).texture = texture;
}
pub fn getTexture(self: *Self, id: nux.ID) !nux.ID {
    return (try self.nodes.get(id)).texture;
}
pub fn setTransform(self: *Self, id: nux.ID, transform: nux.ID) !void {
    (try self.nodes.get(id)).transform = transform;
}
pub fn getTransform(self: *Self, id: nux.ID) !nux.ID {
    return (try self.nodes.get(id)).transform;
}
