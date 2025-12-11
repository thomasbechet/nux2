const nux = @import("../core.zig");
const std = @import("std");

const Self = @This();

pub const TransformDto = struct {
    position: [3]f32 = .{ 0, 1, 2 },
};

pub const Transform = struct {
    position: nux.Vec3,
    pub fn init(self: *@This(), _: *Self) !void {
        self.position = .zero();
        std.log.info("init transform", .{});
    }
    pub fn deinit(_: *@This(), _: *Self) void {}
    pub fn load(self: *@This(), _: *Self, dto: TransformDto) !void {
        self.position.data[0] = dto.position[0];
        self.position.data[1] = dto.position[1];
        self.position.data[2] = dto.position[2];
    }
};

transforms: nux.Objects(Transform, TransformDto, @This()),

pub fn init(self: *Self, core: *nux.Core) !void {
    try self.transforms.init(core, self);

    const t = try self.transforms.new(.null);
    const s =
        \\{
        \\
        \\}
    ;
    const id = self.transforms.getID(t);
    try self.transforms.setJson(id, s);
    std.log.info("{}", .{t});
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
