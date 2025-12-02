const std = @import("std");
const nux = @import("root.zig");

const Vec3 = struct { x: u32, y: u32, z: u32 };

pub const Transform = struct {
    position: Vec3,
    pub fn getPosition(self: *@This()) Vec3 {
        return self.position;
    }
};

const Self = @This();
transforms: nux.Objects(Transform) = .{},

fn init(self: *Self, allocator: std.mem) !void {
    self.transforms.init(allocator);
}
fn deinit(self: *Self) void {
    self.transforms.deinit();
}

pub const ModuleContainer = struct {
    init: *const fn () void,
    deinit: *const fn () void,
};

pub fn getPosition(self: *Self, id: u32) Vec3 {
    return self.transforms.get(id).position;
}
