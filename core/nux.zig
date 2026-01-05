const std = @import("std");

pub const Logger = @import("base/Logger.zig");
pub const Object = @import("base/Object.zig");
pub const Transform = @import("base/Transform.zig");
pub const Input = @import("input/Input.zig");
pub const InputMap = @import("input/InputMap.zig");
pub const Lua = @import("lua/Lua.zig");

pub const ObjectID = Object.ObjectID;
pub const ObjectPool = Object.ObjectPool;
pub const vec = @import("math/vec.zig");
pub const Vec2 = vec.Vec2f;
pub const Vec3 = vec.Vec3f;
pub const Vec4 = vec.Vec4f;

pub const Platform = struct {
    pub const Allocator = std.mem.Allocator;
    pub const Logger = @import("platform/Logger.zig");
    allocator: Platform.Allocator = std.heap.page_allocator,
    logger: Platform.Logger = .default,
};

pub const Module = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    v_ptr: *anyopaque,
    v_call_init: ?*const fn (*anyopaque, core: *Core) anyerror!void,
    v_call_deinit: ?*const fn (*anyopaque) void,
    v_call_update: ?*const fn (*anyopaque) anyerror!void,
    v_destroy: *const fn (*anyopaque, std.mem.Allocator) void,

    pub fn init(comptime T: type, allocator: std.mem.Allocator) !@This() {
        const mod: *T = try allocator.create(T);

        const gen = struct {
            fn call_init(pointer: *anyopaque, core: *Core) anyerror!void {
                const self: *T = @ptrCast(@alignCast(pointer));
                // dependency injection
                inline for (@typeInfo(T).@"struct".fields) |field| {
                    switch (@typeInfo(field.type)) {
                        .pointer => |info| {
                            if (core.findModule(info.child)) |dependency| {
                                if (core.log_enabled) {
                                    core.logger.info("inject {s} to {s}", .{ @typeName(info.child), @typeName(T) });
                                }
                                @field(self, field.name) = dependency;
                            }
                        },
                        else => {},
                    }
                }
                // objects initialization
                try core.object.initModuleObjects(T, self);
                if (@hasDecl(T, "init")) {
                    const ccore: *const Core = core;
                    return self.init(ccore);
                }
            }
            fn call_deinit(pointer: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "deinit")) {
                    self.deinit();
                }
            }
            fn call_update(pointer: *anyopaque) anyerror!void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "update")) {
                    return self.update();
                }
            }
            fn destroy(
                pointer: *anyopaque,
                alloc: std.mem.Allocator,
            ) void {
                const self: *T = @ptrCast(@alignCast(pointer));
                alloc.destroy(self);
            }
        };

        return .{
            .allocator = allocator,
            .name = @typeName(T),
            .v_ptr = mod,
            .v_call_init = gen.call_init,
            .v_call_deinit = gen.call_deinit,
            .v_call_update = gen.call_update,
            .v_destroy = gen.destroy,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.v_destroy(self.v_ptr, self.allocator);
    }
    pub fn call_init(self: *@This(), core: *Core) !void {
        if (self.v_call_init) |call| {
            try call(self.v_ptr, core);
        }
    }
    pub fn call_deinit(self: *@This()) void {
        if (self.v_call_deinit) |call| {
            call(self.v_ptr);
        }
    }
    pub fn call_update(self: *@This()) !void {
        if (self.v_call_update) |call| {
            try call(self.v_ptr);
        }
    }
};

pub const Core = struct {
    modules: std.ArrayList(Module),
    platform: Platform,
    object: *Object,
    logger: *Logger,
    log_enabled: bool,

    pub fn init(platform: Platform, comptime mods: anytype) !*Core {
        var core = try platform.allocator.create(@This());
        core.platform = platform;
        core.modules = try .initCapacity(platform.allocator, 32);
        core.log_enabled = false;

        // Register core modules
        core.logger = try core.registerModule(Logger);
        core.log_enabled = true;
        core.object = try core.registerModule(Object);
        try core.registerModules(.{
            Transform,
            Input,
            InputMap,
            Lua,
        });
        // Register user modules
        try core.registerModules(mods);

        return core;
    }

    pub fn deinit(self: *Core) void {
        var i = self.modules.items.len;
        while (i > 0) : (i -= 1) {
            const module = &self.modules.items[i - 1];
            if (self.log_enabled) {
                self.logger.info("deinit module {s}...", .{module.name});
            }
            module.call_deinit();
        }
        i = self.modules.items.len;
        while (i > 0) : (i -= 1) {
            self.modules.items[i - 1].deinit();
        }
        self.modules.deinit(self.platform.allocator);
        self.platform.allocator.destroy(self);
    }

    pub fn update(self: *Core) !void {
        for (self.modules.items) |*module| {
            try module.call_update();
        }
    }

    pub fn registerModules(self: *Core, comptime mods: anytype) !void {
        const first = self.modules.items.len;
        inline for (mods) |mod| {
            if (self.log_enabled) {
                self.logger.info("register module {s}...", .{@typeName(mod)});
            }
            const module = try self.modules.addOne(self.platform.allocator);
            module.* = try .init(mod, self.platform.allocator);
        }
        for (self.modules.items[first..]) |*module| {
            if (self.log_enabled) {
                self.logger.info("init module {s}...", .{module.name});
            }
            try module.call_init(self);
        }
    }

    pub fn registerModule(self: *Core, comptime T: anytype) !*T {
        try self.registerModules(.{T});
        return self.findModule(T) orelse return undefined;
    }

    pub fn findModule(self: *@This(), comptime T: type) ?*T {
        for (self.modules.items) |*module| {
            if (std.mem.eql(u8, @typeName(T), module.name)) {
                return @ptrCast(@alignCast(module.v_ptr));
            }
        }
        return null;
    }
};

test "core" {
    const ModA = struct {
        objs: ObjectPool(u32),
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
