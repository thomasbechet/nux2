const std = @import("std");
const nux = @import("root.zig");

const Vec3 = struct { x: u32, y: u32, z: u32 };

pub const Transform = struct {
    position: Vec3,
};
const Self = @This();

transforms: nux.Objects(Transform) = .{},

pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    try self.transforms.init(allocator);
}
pub fn deinit(self: *Self) void {
    self.transforms.deinit();
}

pub fn getPosition(self: *Self, id: u32) Vec3 {
    return self.transforms.get(id).position;
}
