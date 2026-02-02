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
    parent: nux.ID = .null,
};

nodes: nux.NodePool(Node),

pub fn save(self: *Self, id: nux.ID, writer: *nux.Writer) !void {
    const n = try self.nodes.get(id);
    try writer.write(n);
}
pub fn load(self: *Self, id: nux.ID, reader: *nux.Reader) !void {
    const n = try self.nodes.get(id);
    n.* = try reader.read(Node);
}
pub fn getProperty(self: *Self, id: nux.ID, prop: Property) !nux.PropertyValue {
    switch (prop) {
        .position => return .{ .vec3 = try self.getPosition(id) },
        .rotation => return .{ .quat = try self.getRotation(id) },
        .scale => return .{ .vec3 = try self.getScale(id) },
        .parent => return .{ .id = try self.getParent(id) },
    }
}
pub fn setProperty(self: *Self, id: nux.ID, prop: Property, value: nux.PropertyValue) !void {
    switch (prop) {
        .position => try self.setPosition(id, value.vec3),
        .rotation => try self.setRotation(id, value.quat),
        .scale => try self.setScale(id, value.vec3),
        .parent => try self.setParent(id, value.id),
    }
}
pub fn getPosition(self: *Self, id: nux.ID) !nux.Vec3 {
    return (try self.nodes.get(id)).position;
}
pub fn setPosition(self: *Self, id: nux.ID, position: nux.Vec3) !void {
    (try self.nodes.get(id)).position = position;
}
pub fn getRotation(self: *Self, id: nux.ID) !nux.Quat {
    return (try self.nodes.get(id)).rotation;
}
pub fn setRotation(self: *Self, id: nux.ID, rotation: nux.Quat) !void {
    (try self.nodes.get(id)).rotation = rotation;
}
pub fn getScale(self: *Self, id: nux.ID) !nux.Vec3 {
    return (try self.nodes.get(id)).scale;
}
pub fn setScale(self: *Self, id: nux.ID, scale: nux.Vec3) !void {
    (try self.nodes.get(id)).scale = scale;
}
pub fn getParent(self: *Self, id: nux.ID) !nux.ID {
    return (try self.nodes.get(id)).parent;
}
pub fn setParent(self: *Self, id: nux.ID, parent: nux.ID) !void {
    (try self.nodes.get(id)).parent = parent;
}
