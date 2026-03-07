const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const Property = enum {
    position,
    rotation,
    scale,
    parent,
};

const Component = struct {
    position: nux.Vec3 = .zero(),
    scale: nux.Vec3 = .scalar(1),
    rotation: nux.Quat = .identity(),
    parent: nux.ID = .null,

    pub fn save(_: *Self, component: *const Component, writer: *nux.Writer) !void {
        try writer.write(component);
    }
    pub fn load(_: *Self, component: *Component, reader: *nux.Reader) !void {
        component.* = try reader.read(Component);
    }
};

components: nux.Components(Component),

pub fn getPosition(self: *Self, id: nux.ID) !nux.Vec3 {
    return (try self.components.get(id)).position;
}
pub fn setPosition(self: *Self, id: nux.ID, position: nux.Vec3) !void {
    (try self.components.get(id)).position = position;
}
pub fn getRotation(self: *Self, id: nux.ID) !nux.Quat {
    return (try self.components.get(id)).rotation;
}
pub fn setRotation(self: *Self, id: nux.ID, rotation: nux.Quat) !void {
    (try self.components.get(id)).rotation = rotation;
}
pub fn getScale(self: *Self, id: nux.ID) !nux.Vec3 {
    return (try self.components.get(id)).scale;
}
pub fn setScale(self: *Self, id: nux.ID, scale: nux.Vec3) !void {
    (try self.components.get(id)).scale = scale;
}
pub fn getParent(self: *Self, id: nux.ID) !nux.ID {
    return (try self.components.get(id)).parent;
}
pub fn setParent(self: *Self, id: nux.ID, parent: nux.ID) !void {
    (try self.components.get(id)).parent = parent;
}
