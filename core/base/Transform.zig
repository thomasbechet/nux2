const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
pub const Property = enum {
    position,
    rotation,
    scale,
    parent,
};
const Node = struct {
    position: nux.Vec3 = .zero(),
    scale: nux.Vec3 = .scalar(1),
    rotation: nux.Quat = .identity(),
    parent: nux.NodeID = .null,
};

nodes: nux.NodePool(Node),

pub fn save(self: *Self, id: nux.NodeID, writer: *nux.Writer) !void {
    const n = try self.nodes.get(id);
    try writer.write(n);
}
pub fn load(self: *Self, id: nux.NodeID, reader: *nux.Reader) !void {
    const n = try self.nodes.get(id);
    n.* = try reader.read(Node);
}
pub fn getProperty(self: *Self, id: nux.NodeID, prop: Property) !nux.PropertyValue {
    switch (prop) {
        .position => return .{ .vec3 = try self.getPosition(id) },
        .rotation => return .{ .quat = try self.getRotation(id) },
        .scale => return .{ .vec3 = try self.getScale(id) },
        .parent => return .{ .id = try self.getParent(id) },
    }
}
pub fn setProperty(self: *Self, id: nux.NodeID, prop: Property, value: nux.PropertyValue) !void {
    switch (prop) {
        .position => try self.setPosition(id, value.vec3),
        .rotation => try self.setRotation(id, value.quat),
        .scale => try self.setScale(id, value.vec3),
        .parent => try self.setParent(id, value.id),
    }
}
pub fn getPosition(self: *Self, id: nux.NodeID) !nux.Vec3 {
    return (try self.nodes.get(id)).position;
}
pub fn setPosition(self: *Self, id: nux.NodeID, position: nux.Vec3) !void {
    (try self.nodes.get(id)).position = position;
}
pub fn getRotation(self: *Self, id: nux.NodeID) !nux.Quat {
    return (try self.nodes.get(id)).rotation;
}
pub fn setRotation(self: *Self, id: nux.NodeID, rotation: nux.Quat) !void {
    (try self.nodes.get(id)).rotation = rotation;
}
pub fn getScale(self: *Self, id: nux.NodeID) !nux.Vec3 {
    return (try self.nodes.get(id)).scale;
}
pub fn setScale(self: *Self, id: nux.NodeID, scale: nux.Vec3) !void {
    (try self.nodes.get(id)).scale = scale;
}
pub fn getParent(self: *Self, id: nux.NodeID) !nux.NodeID {
    return (try self.nodes.get(id)).parent;
}
pub fn setParent(self: *Self, id: nux.NodeID, parent: nux.NodeID) !void {
    (try self.nodes.get(id)).parent = parent;
}
