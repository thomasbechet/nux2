const std = @import("std");
const zlua = @import("zlua");
pub const object = @import("base/object.zig");
pub const ObjectID = object.ObjectID;
pub const Objects = object.Objects;
pub const vec = @import("math/vec.zig");
pub const transform = @import("base/transform.zig");
pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;

const Module = struct {
    pub const Error = error{
        moduleNotFound,
    };

    allocator: std.mem.Allocator,
    name: []const u8,
    v_ptr: *anyopaque,
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
            .v_ptr = mod,
            .v_init = gen.init,
            .v_deinit = gen.deinit,
            .v_update = gen.update,
            .v_destroy = gen.free,
        };
    }
    fn destroy(self: *@This()) void {
        self.v_destroy(self.allocator, self.v_ptr);
    }
    fn init(self: *@This(), core: *Core) !void {
        if (self.v_init) |call| {
            try call(self.v_ptr, core);
        }
    }
    fn deinit(self: *@This()) void {
        if (self.v_deinit) |call| {
            call(self.v_ptr);
        }
    }
    fn update(self: *@This()) !void {
        if (self.v_update) |call| {
            try call(self.v_ptr);
        }
    }
};

pub const OS = struct {};

pub const Core = struct {
    allocator: std.mem.Allocator,
    modules: std.ArrayList(Module),

    object: *object,

    pub fn init(allocator: std.mem.Allocator, comptime mods: anytype) !*Core {
        var core = try allocator.create(@This());
        core.allocator = allocator;
        core.modules = try .initCapacity(allocator, 32);

        // Register core modules
        core.object = try core.registerOne(@import("base/object.zig"));
        try core.register(.{
            @import("base/transform.zig"),
            @import("input/input.zig"),
            @import("input/inputmap.zig"),
        });
        // Register user modules
        try core.register(mods);

        // Initialize the Lua vm
        var lua = try zlua.Lua.init(allocator);
        defer lua.deinit();

        // Add an integer to the Lua stack and retrieve it
        lua.pushInteger(42);
        std.debug.print("{}\n", .{try lua.toInteger(1)});

        const buffer = try std.fs.cwd().readFileAllocOptions(allocator, "test-samples/rigged_simple/RiggedSimple.gltf", 512_000, null, std.mem.Alignment.@"4", null);
        defer allocator.free(buffer);

        return core;
    }

    pub fn deinit(self: *Core) void {
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

    pub fn update(self: *Core) !void {
        for (self.modules.items) |*mod| {
            try mod.update();
        }
    }

    pub fn findModule(self: *Core, comptime T: type) !*T {
        for (self.modules.items) |*mod| {
            if (std.mem.eql(u8, mod.name, @typeName(T))) {
                return @ptrCast(@alignCast(mod.v_ptr));
            }
        }
        return Module.Error.moduleNotFound;
    }

    fn register(self: *Core, comptime mods: anytype) !void {
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

    fn registerOne(self: *Core, comptime T: anytype) !*T {
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
