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
        const id = try self.transform.new(.null);
        self.logger.info("{}", .{id});
    }
    pub fn new(self: *Self, parent: core.ObjectID) !core.ObjectID {
        return self.objects.add(parent, .{ .value = 123 });
    }
    pub fn delete(_: *Self, _: core.ObjectID) void {}
};

export fn instance_init() void {
    const allocator = std.heap.page_allocator;
    var c = core.Core.init(allocator, .{Module}) catch unreachable;
    defer c.deinit();
    c.update() catch unreachable;
}
