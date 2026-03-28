const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Component = struct {
    pub const properties: []const nux.Property.Type = &.{
        .init(Self, nux.Vec3, "position", getPosition, setPosition),
        // .field(Self, nux.Vec3, .scale),
    };

    position: nux.Vec3 = .zero(),
    scale: nux.Vec3 = .scalar(1),
    rotation: nux.Quat = .identity(),
    parent: nux.ID = .null,

    pub fn load(_: *Self, reader: *nux.Reader) !Component {
        return try reader.read(Component);
    }
    pub fn save(self: *const Component, _: *Self, writer: *nux.Writer) !void {
        try writer.write(self);
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
