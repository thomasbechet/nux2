const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

objects: nux.ObjectPool(struct {
    position: nux.Vec3,
}),
object: *nux.Object,
logger: *nux.Logger,

pub fn new(self: *Self, parent: nux.ObjectID) !nux.ObjectID {
    return self.objects.add(parent, .{ .position = .zero() });
}
pub fn delete(self: *Self, id: nux.ObjectID) !void {
    try self.objects.remove(id);
}
pub fn getPosition(self: *Self, id: nux.ObjectID) nux.Vec3 {
    return self.objects.get(id).position;
}
