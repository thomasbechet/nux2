const std = @import("std");
pub const Object = @import("base/object.zig");
pub const ObjectID = Object.ObjectID;
pub const Objects = Object.Objects;

const Module = struct {
    pub const Error = error{
        moduleNotFound,
    };

    allocator: std.mem.Allocator,
    name: []const u8,
    ptr: *anyopaque,
    v_init: ?*const fn (*anyopaque, core: *Core) anyerror!void,
    v_deinit: ?*const fn (*anyopaque) void,
    v_update: ?*const fn (*anyopaque) anyerror!void,
    v_destroy: *const fn (std.mem.Allocator, *anyopaque) void,

    fn create(comptime T: type, allocator: std.mem.Allocator) !@This() {
        const mod: *T = try allocator.create(T);

        const gen = struct {
            const PT = @typeInfo(*T).pointer.child;
            fn init(pointer: *anyopaque, c: *Core) anyerror!void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(PT, "init")) {
                    return PT.init(self, c);
                }
            }
            fn deinit(pointer: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(PT, "deinit")) {
                    PT.deinit(self);
                }
            }
            fn update(pointer: *anyopaque) anyerror!void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(PT, "update")) {
                    return PT.update(self);
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
            .v_destroy = gen.free,
        };
    }
    fn destroy(self: *@This()) void {
        self.v_destroy(self.allocator, self.ptr);
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
    allocator: std.mem.Allocator,
    modules: std.ArrayList(Module),

    object: *Object,

    pub fn init(allocator: std.mem.Allocator, comptime mods: anytype) !*@This() {
        var core = try allocator.create(@This());
        core.allocator = allocator;
        core.modules = try .initCapacity(allocator, 32);

        // Register core modules
        core.object = try core.registerOne(@import("base/object.zig"));
        try core.register(.{@import("base/transform.zig")});
        // Register user modules
        try core.register(mods);

        return core;
    }

    pub fn deinit(self: *@This()) void {
        var i: usize = self.modules.items.len;
        while (i > 0) {
            i -= 1;
            var mod = &self.modules.items[i];
            std.log.info("deinit module {s}...", .{mod.name});
            mod.deinit();
        }
        for (self.modules.items) |*mod| {
            mod.destroy();
        }
        self.modules.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn update(self: *@This()) !void {
        for (self.modules.items) |*mod| {
            try mod.update();
        }
    }

    pub fn findModule(self: *@This(), comptime T: type) !*T {
        for (self.modules.items) |*mod| {
            if (std.mem.eql(u8, mod.name, @typeName(T))) {
                return @ptrCast(@alignCast(mod.ptr));
            }
        }
        return Module.Error.moduleNotFound;
    }

    fn register(self: *@This(), comptime mods: anytype) !void {
        const first = self.modules.items.len;
        inline for (mods) |mod| {
            std.log.info("register module {s}...", .{@typeName(mod)});
            (try self.modules.addOne(self.allocator)).* = try .create(mod, self.allocator);
        }
        for (self.modules.items[first..]) |*mod| {
            std.log.info("init module {s}...", .{mod.name});
            try mod.init(self);
        }
    }

    fn registerOne(self: *@This(), comptime T: anytype) !*T {
        try self.register(.{T});
        return self.findModule(T);
    }
};

test "core" {
    const ModA = struct {
        objs: Objects(u32),
        pub fn init(self: *@This(), core: *Core) !void {
            try self.objs.init(core);
        }
        pub fn deinit(self: *@This()) void {
            self.objs.deinit();
        }
    };
    var core = try Core.init(std.testing.allocator, .{ModA});
    defer core.deinit();
}
