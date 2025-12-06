const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

const Self = @This();

const MyObject = struct {
    value: f32 = 0,
};

const MyModule = struct {
    my_objects: nux.Objects(MyObject),

    pub fn init(self: *@This(), core: *nux.Core) !void {
        std.log.info("Hello from MyModule", .{});
        self.my_objects = try .init(core);
    }

    pub fn update(self: *@This()) !void {
        for (0..10) |_| {
            const id = try self.my_objects.new();
            std.log.info("{}", .{id});
        }
    }
};

const MyModuleB = struct {
    my_module: *MyModule,
    pub fn init(self: *@This(), core: *nux.Core) !void {
        self.my_module = try core.findModule(MyModule);
    }
};

const MyModuleC = struct {
    my_module: *MyModuleB,
    my_objects: nux.Objects(MyObject),
    pub fn init(self: *@This(), core: *nux.Core) !void {
        self.my_module = try core.findModule(MyModuleB);
        self.my_objects = try .init(core);
    }
    pub fn update(self: *@This()) !void {
        const id = try self.my_objects.new();
        std.log.info("{}", .{id});
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var core = try nux.Core.init(allocator, .{ MyModule, MyModuleC, MyModuleB });
    defer core.deinit();
    try core.update();
    var context = window.Context{};
    try context.init();
}
