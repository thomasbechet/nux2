const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

components: nux.Components(struct {
    texture: nux.ID = .null,
    mesh: nux.ID = .null,
    transform: nux.ID = .null,
}),
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn setMesh(self: *Self, id: nux.ID, mesh: nux.ID) !void {
    (try self.components.get(id)).mesh = mesh;
}
pub fn getMesh(self: *Self, id: nux.ID) !nux.ID {
    return (try self.components.get(id)).mesh;
}
pub fn setTexture(self: *Self, id: nux.ID, texture: nux.ID) !void {
    (try self.components.get(id)).texture = texture;
}
pub fn getTexture(self: *Self, id: nux.ID) !nux.ID {
    return (try self.components.get(id)).texture;
}
pub fn setTransform(self: *Self, id: nux.ID, transform: nux.ID) !void {
    (try self.components.get(id)).transform = transform;
}
pub fn getTransform(self: *Self, id: nux.ID) !nux.ID {
    return (try self.components.get(id)).transform;
}
