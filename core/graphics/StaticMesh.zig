const std = @import("std");
const nux = @import("../nux.zig");

const Module = @This();
const Node = struct {
    texture: nux.NodeID = .null,
    mesh: nux.NodeID = .null,
    transform: nux.NodeID = .null,
    pub fn init(_: *Module) !@This() {
        return .{};
    }
};

nodes: nux.NodePool(Node),
allocator: std.mem.Allocator,

pub fn init(self: *Module, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn setMesh(self: *Module, id: nux.NodeID, mesh: nux.NodeID) !void {
    (try self.nodes.get(id)).mesh = mesh;
}
pub fn getMesh(self: *Module, id: nux.NodeID) !nux.NodeID {
    return (try self.nodes.get(id)).mesh;
}
pub fn setTexture(self: *Module, id: nux.NodeID, texture: nux.NodeID) !void {
    (try self.nodes.get(id)).texture = texture;
}
pub fn getTexture(self: *Module, id: nux.NodeID) !nux.NodeID {
    return (try self.nodes.get(id)).texture;
}
pub fn setTransform(self: *Module, id: nux.NodeID, transform: nux.NodeID) !void {
    (try self.nodes.get(id)).transform = transform;
}
pub fn getTransform(self: *Module, id: nux.NodeID) !nux.NodeID {
    return (try self.nodes.get(id)).transform;
}
