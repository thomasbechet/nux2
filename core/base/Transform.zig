const std = @import("std");
const nux = @import("../nux.zig");

const Module = @This();
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
    pub fn init(_: *Module) !@This() {
        return .{};
    }
    pub fn deinit(_: *@This(), _: *Module) void {}
    pub fn save(self: *@This(), _: *Module, writer: *nux.Writer) !void {
        try writer.write(self.*);
    }
    pub fn load(self: *@This(), _: *Module, reader: *nux.Reader) !void {
        self.* = try reader.read(@This());
    }
    pub fn getProperty(id: nux.NodeID, mod: *Module, prop: Property) !nux.PropertyValue {
        switch (prop) {
            .position => return .{ .vec3 = mod.getPosition(id) },
            .rotation => return .{ .quat = mod.getRotation(id) },
            .scale => return .{ .vec3 = mod.getScale(id) },
            .parent => return .{ .id = mod.getParent(id) },
        }
    }
    pub fn setProperty(id: nux.NodeID, mod: *Module, prop: Property, value: nux.PropertyValue) void {
        switch (prop) {
            .position => mod.setPosition(id, value.vec3),
            .rotation => mod.setRotation(id, value.quat),
            .scale => mod.setScale(id, value.vec3),
            .parent => mod.setParent(id, value.id),
        }
    }
};

nodes: nux.NodePool(Node),

pub fn new(self: *Module, parent: nux.NodeID) !nux.NodeID {
    return (try self.nodes.new(parent)).id;
}
pub fn getPosition(self: *Module, id: nux.NodeID) !nux.Vec3 {
    return (try self.nodes.get(id)).position;
}
pub fn setPosition(self: *Module, id: nux.NodeID, position: nux.Vec3) !void {
    (try self.nodes.get(id)).position = position;
}
pub fn getRotation(self: *Module, id: nux.NodeID) !nux.Quat {
    return (try self.nodes.get(id)).rotation;
}
pub fn setRotation(self: *Module, id: nux.NodeID, rotation: nux.Quat) !void {
    (try self.nodes.get(id)).rotation = rotation;
}
pub fn getScale(self: *Module, id: nux.NodeID) !nux.Vec3 {
    return (try self.nodes.get(id)).scale;
}
pub fn setScale(self: *Module, id: nux.NodeID, scale: nux.Vec3) !void {
    (try self.nodes.get(id)).scale = scale;
}
pub fn getParent(self: *Module, id: nux.NodeID) !nux.NodeID {
    return (try self.nodes.get(id)).parent;
}
pub fn setParent(self: *Module, id: nux.NodeID, parent: nux.NodeID) !void {
    (try self.nodes.get(id)).parent = parent;
}
