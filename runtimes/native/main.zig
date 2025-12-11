const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

const Config = struct {
    root: []const u8 = "/tmp/demo",
};

fn readConfig(allocator: std.mem.Allocator, path: []const u8) !std.json.Parsed(Config) {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 512);
    defer allocator.free(data);
    return std.json.parseFromSlice(Config, allocator, data, .{ .allocate = .alloc_always });
}

const MyObject = struct {
    const DTO = struct {
        value: ?u32 = null,
    };
    value: u32,

    pub fn load(self: *@This(), _: *Module, dto: DTO) !void {
        if (dto.value) |v| self.value = v;
    }

    pub fn store(self: *@This()) !DTO {
        return .{ .value = self.value };
    }
};

const Module = struct {
    const Self = @This();

    objects: nux.Objects(MyObject, MyObject.DTO, Self),

    pub fn init(self: *Self, core: *nux.Core) !void {
        try self.objects.init(core, self);

        const id = self.objects.getID(try self.objects.new(.null));
        const s =
            \\{ "value": 666}
        ;
        try self.objects.setJson(id, s);
        std.log.info("{any}", .{try self.objects.get(id)});
        std.log.info("{any}", .{try self.objects.getDTO(id)});
        var buf: [2048]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const json = try self.objects.getJson(id, fba.allocator());
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
