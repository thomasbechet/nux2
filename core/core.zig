const std = @import("std");
pub const Objects = @import("object.zig").Objects;

pub const Core = struct {
    allocator: std.mem.Allocator = undefined,
    objects: @import("object.zig"),
    modules: @import("module.zig"),

    pub fn init(allocator: std.mem.Allocator, comptime mods: anytype) !*@This() {
        var core = try allocator.create(@This());
        core.allocator = allocator;
        core.objects = try .init(allocator);
        core.modules = try .init(allocator);
        try core.modules.register(core, mods);
        return core;
    }

    pub fn deinit(self: *@This()) void {
        self.objects.deinit();
        self.modules.deinit();
        self.allocator.destroy(self);
    }

    pub fn update(self: *@This()) !void {
        try self.modules.update();
    }

    pub fn findModule(self: *const @This(), comptime T: type) !*T {
        return self.modules.find(T);
    }
};

test "core" {
    const ModA = struct {
        objs: Objects(u32),
        pub fn init(self: *@This(), core: *Core) !void {
            self.objs = try .init(core);
        }
        pub fn deinit(self: *@This()) void {
            self.objs.deinit();
        }
    };
    var core = try Core.init(std.testing.allocator, .{ModA});
    defer core.deinit();
}
