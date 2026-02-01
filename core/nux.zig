const std = @import("std");

pub const Logger = @import("base/Logger.zig");
pub const Node = @import("base/Node.zig");
pub const Disk = @import("base/Disk.zig");
pub const Transform = @import("base/Transform.zig");
pub const Input = @import("input/Input.zig");
pub const InputMap = @import("input/InputMap.zig");
pub const Lua = @import("lua/Lua.zig");
pub const SourceFile = @import("base/SourceFile.zig");
pub const Script = @import("base/Script.zig");
pub const Graphics = @import("graphics/Graphics.zig");
pub const Texture = @import("graphics/Texture.zig");
pub const Mesh = @import("graphics/Mesh.zig");
pub const Material = @import("graphics/Material.zig");
pub const StaticMesh = @import("graphics/StaticMesh.zig");
pub const Camera = @import("graphics/Camera.zig");

pub const NodeID = Node.NodeID;
pub const NodePool = Node.NodePool;
pub const Writer = Node.Writer;
pub const Reader = Node.Reader;
pub const vec = @import("math/vec.zig");
pub const Vec2 = vec.Vec2f;
pub const Vec3 = vec.Vec3f;
pub const Vec4 = vec.Vec4f;
pub const quat = @import("math/quat.zig");
pub const Quat = quat.Quat;

pub const Platform = struct {
    pub const Allocator = std.mem.Allocator;
    pub const Logger = @import("platform/Logger.zig");
    pub const Input = @import("platform/Input.zig");
    pub const File = @import("platform/File.zig");
    pub const Dir = @import("platform/Dir.zig");
    pub const Event = union(enum) {
        input: Platform.Input.Event,
    };
    allocator: Platform.Allocator = std.heap.page_allocator,
    logger: Platform.Logger = .default,
    file: Platform.File = .default,
    dir: Platform.Dir = .default,
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
                                if (core.config.logModuleInjection) {
                                    core.log("inject {s} to {s}", .{ @typeName(info.child), @typeName(T) });
                                }
                                @field(self, field.name) = dependency;
                            }
                        },
                        else => {},
                    }
                }
                // nodes initialization
                if (T != Node) { // Node will register itself as node module
                    if (core.findModule(Node)) |node| {
                        try node.registerNodeModule(self);
                    }
                }
                // initialize
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

pub const Config = struct {
    logModuleInjection: bool = false,
};

pub const Core = struct {
    modules: std.ArrayList(Module),
    platform: Platform,
    config: Config,

    fn log(
        self: *Core,
        comptime format: []const u8,
        args: anytype,
    ) void {
        if (self.findModule(Logger)) |logger| {
            logger.info(format, args);
        }
    }

    pub fn init(platform: Platform, config: Config, comptime mods: anytype) !*Core {
        var core = try platform.allocator.create(@This());
        core.platform = platform;
        core.modules = try .initCapacity(platform.allocator, 32);
        core.config = config;

        // Register core modules
        try core.registerModules(.{Logger});
        try core.registerModules(.{
            Node,
            Input,
            Disk,
            Transform,
            InputMap,
            SourceFile,
            Script,
            Graphics,
            Texture,
            Lua,
        });

        // Register user modules
        try core.registerModules(mods);

        // Call entry point
        errdefer core.deinit();
        var lua = core.findModule(Lua) orelse unreachable;
        try lua.callEntryPoint();

        return core;
    }

    pub fn deinit(self: *Core) void {
        if (self.findModule(Node)) |node| {
            node.delete(node.getRoot()) catch {};
        }

        var i = self.modules.items.len;
        while (i > 0) : (i -= 1) {
            const module = &self.modules.items[i - 1];
            if (self.config.logModuleInjection) {
                self.log("deinit module {s}...", .{module.name});
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

    pub fn pushEvent(self: *Core, event: Platform.Event) void {
        const input = self.findModule(Input) orelse return;
        switch (event) {
            .input => |e| input.onEvent(e),
        }
    }

    pub fn registerModules(self: *Core, comptime mods: anytype) !void {
        const first = self.modules.items.len;
        inline for (mods) |mod| {
            self.log("register module {s}...", .{@typeName(mod)});
            const module = try self.modules.addOne(self.platform.allocator);
            module.* = try .init(mod, self.platform.allocator);
        }
        for (self.modules.items[first..]) |*module| {
            if (self.config.logModuleInjection) {
                self.log("init module {s}...", .{module.name});
            }
            try module.call_init(self);
        }
    }

    pub fn findModule(self: *const @This(), comptime T: type) ?*T {
        for (self.modules.items) |*module| {
            if (std.mem.eql(u8, @typeName(T), module.name)) {
                return @ptrCast(@alignCast(module.v_ptr));
            }
        }
        return null;
    }
};
