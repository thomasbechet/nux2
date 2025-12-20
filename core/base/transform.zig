const nux = @import("../core.zig");
const std = @import("std");

const Module = @This();

const Transform = struct {
    const Context = Module;
    const Self = @This();
    const Data = struct {
        position: ?[3]f32 = null,
    };

    position: nux.Vec3,

    pub fn init(self: *Self, _: *Context) !void {
        self.position = .zero();
    }
    pub fn deinit(_: *Self, _: *Context) void {}
    pub fn load(self: *Self, _: *Module, data: Data) !void {
        if (data.position) |position| {
            self.position.data[0] = position[0];
            self.position.data[1] = position[1];
            self.position.data[2] = position[2];
        }
    }
    pub fn save(_: *Self, _: *Module) !Data {
        return .{};
    }
};

object: *nux.Module(Object),
transforms: *nux.Objects(Transform),

pub fn init(self: *@This(), core: *nux.Core) !void {
    self.transforms = try .init(core);
}
pub fn deinit(_: *@This()) !void {}

pub fn new(self: *@This()) !nux.ObjectID {
    return try self.transforms.new(.null);
}
pub fn delete(self: *@This(), id: nux.ObjectID) !void {}
pub fn getPosition(self: *@This(), id: nux.ObjectID) nux.Vec3 {
    return self.transforms.get(id).position;
}
