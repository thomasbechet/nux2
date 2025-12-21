const nux = @import("../core.zig");
const std = @import("std");

const Transform = struct {
    const Data = struct {
        position: ?[3]f32 = null,
    };
    position: nux.Vec3,
};

pub const Module = struct {
    object: *nux.object.Module,
    transforms: *nux.Objects(Transform),

    pub fn init(self: *@This(), core: *nux.Core) !void {
        self.object = core.object;
        self.transforms = try core.object.register(self, .{
            .type = Transform,
            .data = Transform.Data,
            .new = Module.new,
            .delete = Module.delete,
            .load = Module.load,
            .save = Module.save,
        });

        var toremove: nux.ObjectID = undefined;
        for (0..100) |i| {
            // const id = try self.new(.null);
            const id = try self.object.new(@typeName(Transform), .null);
            if (i == 54) {
                toremove = id;
            }
        }
        try self.transforms.remove(toremove);
        _ = try self.transforms.add(.null);
        for (self.transforms.ids.items) |id| {
            std.log.info("{}", .{id});
        }
    }
    pub fn deinit(_: *Module) void {}

    pub fn new(self: *Module, parent: nux.ObjectID) !nux.ObjectID {
        const id, _ = try self.transforms.add(parent);
        std.log.info("hello world", .{});
        return id;
    }
    pub fn delete(_: *Module, _: nux.ObjectID) !void {}
    pub fn load(self: *Module, id: nux.ObjectID, data: *Transform.Data) !void {
        var obj = try self.transforms.get(id);
        if (data.position) |position| {
            obj.position.data[0] = position[0];
            obj.position.data[1] = position[1];
            obj.position.data[2] = position[2];
        }
    }
    pub fn save(_: *Module, _: nux.ObjectID) !Transform.Data {
        return .{};
    }
    pub fn getPosition(self: *Module, id: nux.ObjectID) nux.Vec3 {
        return self.transforms.get(id).position;
    }
};
