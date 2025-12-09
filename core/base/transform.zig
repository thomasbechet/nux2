const nux = @import("../core.zig");
const std = @import("std");

const Self = @This();

pub const Transform = struct {
    position: nux.Vec3,
    pub fn init(self: *@This(), _: *Self) !void {
        self.position = .zero();
        std.log.info("init transform", .{});
    }
    pub fn deinit(_: *@This(), _: *Self) void {}
};

transforms: nux.Objects(Transform, @This()),

pub fn init(self: *Self, core: *nux.Core) !void {
    try self.transforms.init(core, self);
}
pub fn deinit(self: *Self) void {
    self.transforms.deinit();
}

pub fn new(self: *Self) !nux.ObjectID {
    const p = try self.transforms.new(.null);
    return self.transforms.getID(p);
}
pub fn getPosition(self: *Self, id: nux.ObjectID) nux.Vec3 {
    return self.transforms.get(id).position;
}
