const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

const Config = struct {
    root: []const u8 = "/tmp/demo",
};

const Module = struct {
    const Self = @This();

    const MyObject = struct {
        value: u32,
    };

    objects: *nux.Objects(MyObject),
    object: *nux.object.Module,

    pub fn init(self: *Self, core: *nux.Core) !void {
        self.object = core.object;
        self.objects = try core.object.register(MyObject, self, .{});

        const root = try self.objects.new(.null);
        _ = try self.objects.new(root);
        self.object.dump(root);
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
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var core = try nux.Core.init(allocator, .{Module});
    defer core.deinit();
    try core.update();
    var context = window.Context{};
    try context.run(core);
}
