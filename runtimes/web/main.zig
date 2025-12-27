const std = @import("std");
const core = @import("core");

const Module = struct {
    const Self = @This();

    const MyObject = struct {
        value: u32,
    };

    objects: core.ObjectPool(MyObject),
    object: *core.Object,
    transform: *core.Transform,
    logger: *core.Logger,

    pub fn init(self: *Self, c: *core.Core) !void {
        self.object = c.object;

        // const id = try self.object.new(@typeName(MyObject), .null);
        // std.log.info("{any}", .{id});
        // try self.object.delete(id);
        //
        // const root, _ = try self.objects.add(.null);
        // _, _ = try self.objects.add(root);
        // self.object.dump(root);
        // const s =
        //     \\{ "value": 666 }
        // ;
        // // try self.objects.loadJson(id, s);
        // std.log.info("{any}", .{id});
        // try self.object.loadJson(id, s);
        // std.log.info("{any}", .{try self.objects.get(id)});
        //
        // var buf: [2048]u8 = undefined;
        // var fba = std.heap.FixedBufferAllocator.init(&buf);
        // const json = try self.object.saveJson(id, fba.allocator());
        // std.log.info("{s}", .{json.items});
        const id = try self.transform.new(.null);
        self.logger.info("{}", .{id});
    }
    pub fn new(self: *Self, parent: core.ObjectID) !core.ObjectID {
        return self.objects.add(parent, .{ .value = 123 });
    }
    pub fn delete(_: *Self, _: core.ObjectID) void {}
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var c = try core.Core.init(allocator, .{Module});
    defer c.deinit();
    try c.update();
}
