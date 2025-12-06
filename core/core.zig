const std = @import("std");
pub const Objects = @import("object.zig").Objects;

const Module = struct {
    const VTable = struct {};

    allocator: std.mem.Allocator,
    name: []const u8,
    ptr: *anyopaque,
    v_init: ?*const fn (*anyopaque, core: *Core) anyerror!void,
    v_deinit: ?*const fn (*anyopaque) void,
    v_update: ?*const fn (*anyopaque) anyerror!void,
    v_free: *const fn (std.mem.Allocator, *anyopaque) void,

    fn create(comptime T: type, allocator: std.mem.Allocator) !@This() {
        const mod: *T = try allocator.create(T);

        const gen = struct {
            fn init(pointer: *anyopaque, c: *Core) anyerror!void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "init")) {
                    return @typeInfo(*T).pointer.child.init(self, c);
                }
            }
            fn deinit(pointer: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "deinit")) {
                    @typeInfo(*T).pointer.child.deinit(self);
                }
            }
            fn update(pointer: *anyopaque) anyerror!void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "update")) {
                    return @typeInfo(*T).pointer.child.update(self);
                }
            }
            fn free(alloc: std.mem.Allocator, pointer: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(pointer));
                alloc.destroy(self);
            }
        };

        return .{
            .allocator = allocator,
            .name = @typeName(T),
            .ptr = mod,
            .v_init = gen.init,
            .v_deinit = gen.deinit,
            .v_update = gen.update,
            .v_free = gen.free,
        };
    }
    fn destroy(self: *@This()) void {
        self.v_free(self.allocator, self.ptr);
    }
    fn init(self: *@This(), core: *Core) !void {
        if (self.v_init) |call| {
            try call(self.ptr, core);
        }
    }
    fn deinit(self: *@This()) void {
        if (self.v_deinit) |call| {
            call(self.ptr);
        }
    }
    fn update(self: *@This()) !void {
        if (self.v_update) |call| {
            try call(self.ptr);
        }
    }
};

pub const Core = struct {
    const Error = error{
        moduleNotFound,
    };

    allocator: std.mem.Allocator = undefined,
    objects: @import("object.zig"),
    modules: std.ArrayList(Module),

    pub fn init(allocator: std.mem.Allocator, comptime mods: anytype) !*@This() {
        var core = try allocator.create(@This());
        core.allocator = allocator;
        core.objects = try .init(allocator);
        core.modules = try .initCapacity(allocator, 32);
        // Create modules
        inline for (mods) |mod| {
            (try core.modules.addOne(allocator)).* = try .create(mod, allocator);
        }
        // Init modules
        for (core.modules.items) |*mod| {
            try mod.init(core);
        }
        return core;
    }

    pub fn deinit(self: *@This()) void {
        // Deinit modules
        for (self.modules.items) |*mod| {
            mod.deinit();
        }
        // Destry modules
        for (self.modules.items) |*mod| {
            mod.destroy();
        }
        self.objects.deinit();
        self.modules.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn update(self: *@This()) !void {
        // Deinit modules
        for (self.modules.items) |*mod| {
            try mod.update();
        }
    }

    pub fn findModule(self: *const @This(), comptime T: type) !*T {
        for (self.modules.items) |*mod| {
            if (std.mem.eql(u8, mod.name, @typeName(T))) {
                return @ptrCast(@alignCast(mod.ptr));
            }
        }
        return Error.moduleNotFound;
    }
};

test "core" {
    const ModA = struct {
        objs: Objects(u32),
        fn init(self: *@This(), core: *Core) !void {
            self.objs = try .init(core);
        }
        fn deinit(self: *@This()) void {
            self.objs.deinit();
        }
    };
    var core = try Core.init(std.testing.allocator, .{ModA});
    defer core.deinit();
}
