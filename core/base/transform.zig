const nux = @import("../core.zig");

const Vec3 = struct { x: u32, y: u32, z: u32 };

pub const Transform = struct {
    position: Vec3,
};

transforms: nux.Objects(Transform),

pub fn init(self: *@This(), core: *nux.Core) !void {
    try self.transforms.init(core);
}
pub fn deinit(self: *@This()) void {
    self.transforms.deinit();
}

pub fn getPosition(self: *@This(), id: nux.ObjectID) Vec3 {
    return self.transforms.get(id).position;
}
