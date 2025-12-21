const std = @import("std");
const zlua = @import("zlua");
const zigimg = @import("zigimg");

pub const object = @import("base/object.zig");
pub const transform = @import("base/transform.zig");

pub const ObjectID = object.ObjectID;
pub const Objects = object.ObjectPool;
pub const vec = @import("math/vec.zig");
pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;

pub const Module = struct {
    pub const Error = error{
        moduleNotFound,
    };

    allocator: std.mem.Allocator,
    name: []const u8,
    v_ptr: *anyopaque,
    v_init: ?*const fn (*anyopaque, core: *Core) anyerror!void,
    v_deinit: ?*const fn (*anyopaque) void,
    v_update: ?*const fn (*anyopaque) anyerror!void,
    v_destroy: *const fn (*anyopaque, std.mem.Allocator) void,

    pub fn init(comptime T: type, allocator: std.mem.Allocator) !@This() {
        const mod: *T = try allocator.create(T);

        const gen = struct {
            const PT = @typeInfo(*T).pointer.child;
            fn init(pointer: *anyopaque, c: *Core) anyerror!void {
                const self: *T = @ptrCast(@alignCast(pointer));
                inline for (@typeInfo(T).@"struct".fields) |field| {
                    if (@typeInfo(field.type) == .@"struct" and @hasDecl(field.type, "IsObjects")) {}
                }
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
            fn free(
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
            .v_init = gen.init,
            .v_deinit = gen.deinit,
            .v_update = gen.update,
            .v_destroy = gen.free,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.v_destroy(self.v_ptr, self.allocator);
    }
    pub fn call_init(self: *@This(), core: *Core) !void {
        if (self.v_init) |call| {
            try call(self.v_ptr, core);
        }
    }
    pub fn call_deinit(self: *@This()) void {
        if (self.v_deinit) |call| {
            call(self.v_ptr);
        }
    }
    pub fn call_update(self: *@This()) !void {
        if (self.v_update) |call| {
            try call(self.v_ptr);
        }
    }
};

pub const Core = struct {
    allocator: std.mem.Allocator,
    modules: std.StringHashMap(Module),
    object: *object.Module,

    pub fn init(allocator: std.mem.Allocator, comptime mods: anytype) !*Core {
        var core = try allocator.create(@This());
        core.allocator = allocator;
        core.modules = .init(allocator);

        // Register core modules
        core.object = try core.registerModule(object.Module);
        try core.registerModules(.{
            @import("base/transform.zig").Module,
            @import("input/input.zig").Module,
            @import("input/inputmap.zig").Module,
        });
        // Register user modules
        try core.registerModules(mods);

        // // Initialize the Lua vm
        // var lua = try zlua.Lua.init(allocator);
        // defer lua.deinit();
        //
        // var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE * 10]u8 = undefined;
        // var image = try zigimg.Image.fromFilePath(allocator, "pannel22.jpg", read_buffer[0..]);
        // defer image.deinit(allocator);
        //
        // // Add an integer to the Lua stack and retrieve it
        // lua.pushInteger(42);
        // std.debug.print("{}\n", .{try lua.toInteger(1)});
        //
        // const buffer = try std.fs.cwd().readFileAllocOptions(allocator, "test-samples/rigged_simple/RiggedSimple.gltf", 512_000, null, std.mem.Alignment.@"4", null);
        // defer allocator.free(buffer);

        return core;
    }

    pub fn deinit(self: *Core) void {
        var it = self.modules.iterator();
        while (it.next()) |entry| {
            std.log.info("deinit module {s}...", .{entry.key_ptr.*});
            entry.value_ptr.call_deinit();
        }
        it = self.modules.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.modules.deinit();
        self.allocator.destroy(self);
    }

    pub fn update(self: *Core) !void {
        var it = self.modules.iterator();
        while (it.next()) |entry| {
            try entry.value_ptr.call_update();
        }
    }

    pub fn registerModules(self: *Core, comptime mods: anytype) !void {
        inline for (mods) |mod| {
            std.log.info("register module {s}...", .{@typeName(mod)});
            try self.modules.put(@typeName(mod), try .init(mod, self.allocator));
        }
        inline for (mods) |mod| {
            std.log.info("init module {s}...", .{@typeName(mod)});
            try self.modules.getPtr(@typeName(mod)).?.call_init(self);
        }
    }

    pub fn registerModule(self: *Core, comptime T: anytype) !*T {
        try self.registerModules(.{T});
        return self.getModule(T);
    }

    pub fn getModule(self: *@This(), comptime T: type) !*T {
        if (self.modules.getPtr(@typeName(T))) |mod| {
            return @ptrCast(@alignCast(mod.v_ptr));
        }
        return Module.Error.moduleNotFound;
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
