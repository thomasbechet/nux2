const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

const Config = struct {
    root: []const u8 = "/tmp/demo",
};

const MyObject = struct {
    const Properties = struct {
        value: ?u32 = null,
    };

    value: u32,

    pub fn load(self: *@This(), _: *Module, props: Properties) !void {
        if (props.value) |v| self.value = v;
    }
    pub fn save(self: *@This(), _: *Module) !Properties {
        return .{ .value = self.value };
    }
};

const Module = struct {
    const Self = @This();

    objects: nux.Objects(MyObject, MyObject.Properties, Self),
    object: *nux.object,

    pub fn init(self: *Self, core: *nux.Core) !void {
        try self.objects.init(core, self);
        self.object = try core.findModule(nux.object);

        const id = try self.objects.new(.null);
        const s =
            \\{ "value": 666 }
        ;
        // try self.objects.loadJson(id, s);
        std.log.info("{any}", .{id});
        try self.object.loadJson(id, s);
        std.log.info("{any}", .{try self.objects.get(id)});

        var buf: [2048]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const json = try self.object.saveJson(id, fba.allocator());
        std.log.info("{s}", .{json.items});
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
