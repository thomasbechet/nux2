const nux = @import("../core.zig");
const std = @import("std");

const Self = @This();

pub const Transform = struct {
    const DTO = struct {
        position: ?[3]f32 = null,
    };

    position: nux.Vec3,
    pub fn init(self: *@This(), _: *Self) !void {
        self.position = .zero();
    }
    pub fn deinit(_: *@This(), _: *Self) void {}
    pub fn load(self: *@This(), _: *Self, dto: DTO) !void {
        if (dto.position) |position| {
            self.position.data[0] = position[0];
            self.position.data[1] = position[1];
            self.position.data[2] = position[2];
        }
    }
    pub fn save(_: *@This(), _: *Self) !DTO {
        return .{};
    }
};

transforms: nux.Objects(Transform, Transform.DTO, @This()),

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
