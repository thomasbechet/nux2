const std = @import("std");
const zlua = @import("zlua");
const zigimg = @import("zigimg");
const object = @import("object.zig");
const module = @import("module.zig");

pub const ObjectID = object.ObjectID;
pub const Objects = object.Objects;
pub const vec = @import("math/vec.zig");
pub const transform = @import("base/transform.zig");
pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;

pub const Core = struct {
    allocator: std.mem.Allocator,
    object: object.Module,
    module: *@import("module.zig"),

    pub fn init(allocator: std.mem.Allocator, comptime mods: anytype) !*Core {
        var core = try allocator.create(@This());
        core.allocator = allocator;
        core.module = .init(allocator);
        core.object = .init(allocator);

        // Register core modules
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
            entry.value_ptr.deinit();
        }
        it = self.modules.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.destroy();
        }
        self.modules.deinit();
        self.module.deinit();
        self.allocator.destroy(self);
    }

    pub fn update(self: *Core) !void {
        var it = self.modules.iterator();
        while (it.next()) |entry| {
            try entry.value_ptr.update();
        }
    }

    fn registerModules(self: *Core, comptime mods: anytype) !void {
        inline for (mods) |mod| {
            std.log.info("register module {s}...", .{@typeName(mod)});
            try self.modules.put(@typeName(mod), try .create(mod, self.allocator));
        }
        inline for (mods) |mod| {
            std.log.info("init module {s}...", .{@typeName(mod)});
            try self.modules.getPtr(@typeName(mod)).?.init(self);
        }
    }

    fn registerModule(self: *Core, comptime T: anytype) !*T {
        try self.registerModules(.{T});
        return self.getModule(T);
    }

    pub fn getModule(self: *Core, comptime T: type) !*T {
        return self.module.getModule(T);
    }

    pub fn registerObject(self: *Core, comptime T: type) !*Objects(T) {
        return try self.objects.put(@typeName(T), .init(self));
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
