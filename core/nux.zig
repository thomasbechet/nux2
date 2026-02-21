const std = @import("std");

pub const Logger = @import("base/Logger.zig");
pub const Config = @import("base/Config.zig");
pub const Node = @import("base/Node.zig");
pub const Signal = @import("base/Signal.zig");
pub const File = @import("base/File.zig");
pub const Cart = @import("base/Cart.zig");
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
pub const GUI = @import("gui/GUI.zig");
pub const Window = @import("graphics/Window.zig");
pub const Vertex = @import("graphics/Vertex.zig");

pub const ID = Node.ID;
pub const PropertyValue = Node.PropertyValue;
pub const NodePool = Node.NodePool;
pub const Writer = Node.Writer;
pub const Reader = Node.Reader;
pub const vec = @import("math/vec.zig");
pub const Vec2 = vec.Vec2f;
pub const Vec3 = vec.Vec3f;
pub const Vec4 = vec.Vec4f;
pub const quat = @import("math/quat.zig");
pub const Quat = quat.Quat;
pub const SpanAllocator = @import("utils/SpanAllocator.zig");
pub const Callable = @import("utils/Callable.zig");
pub const Deque = @import("utils/Deque.zig").Deque; // TODO: wait 0.16.0 for std

pub const Platform = struct {
    pub const Allocator = std.mem.Allocator;
    pub const Logger = @import("platform/Logger.zig");
    pub const Input = @import("platform/Input.zig");
    pub const Window = @import("platform/Window.zig");
    pub const File = @import("platform/File.zig");
    pub const GPU = @import("platform/GPU.zig");
    pub const Event = union(enum) {
        keyPressed: Platform.Input.KeyPressed,
        windowResized: Platform.Window.WindowResized,
        requestExit,
    };
    pub const Config = struct {
        logModuleInitialization: bool = false,
        command: union(enum) {
            run: struct {
                script: []const u8 = "init.lua",
            },
            build: struct { path: []const u8 = "cart.bin", glob: []const u8 = "*" },
        } = .{ .run = .{} },
        mount: ?[]const u8 = null,
    };
    allocator: Platform.Allocator = std.heap.page_allocator,
    logger: Platform.Logger = .{},
    file: Platform.File = .{},
    window: Platform.Window = .{},
    gpu: Platform.GPU = .{},

    config: Platform.Config = .{},
};

const Stage = enum { pre_update, update, post_update };

pub const Module = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    v_ptr: *anyopaque,
    v_call_init: ?*const fn (*anyopaque, core: *Core) anyerror!void,
    v_call_deinit: ?*const fn (*anyopaque) void,
    v_destroy: *const fn (*anyopaque, std.mem.Allocator) void,

    pub fn init(comptime T: type, allocator: std.mem.Allocator) !@This() {
        const mod: *T = try allocator.create(T);

        const gen = struct {
            fn callInit(pointer: *anyopaque, core: *Core) anyerror!void {
                const self: *T = @ptrCast(@alignCast(pointer));
                // Dependency injection
                inline for (@typeInfo(T).@"struct".fields) |field| {
                    switch (@typeInfo(field.type)) {
                        .pointer => |info| {
                            if (core.findModule(info.child)) |dependency| {
                                if (core.platform.config.logModuleInitialization) {
                                    core.log("inject {s} to {s}", .{ @typeName(info.child), @typeName(T) });
                                }
                                @field(self, field.name) = dependency;
                            }
                        },
                        else => {},
                    }
                }
                // Nodes initialization
                if (T != Node) { // Node will register itself as node module
                    if (core.findModule(Node)) |node| {
                        try node.registerNodeModule(self);
                    }
                }
                // Register callbacks
                if (@hasDecl(T, "onPreUpdate")) {
                    try core.registerStageCallback(.pre_update, .wrap(T, T.onPreUpdate, self));
                }
                if (@hasDecl(T, "onUpdate")) {
                    try core.registerStageCallback(.update, .wrap(T, T.onUpdate, self));
                }
                if (@hasDecl(T, "onPostUpdate")) {
                    try core.registerStageCallback(.post_update, .wrap(T, T.onPostUpdate, self));
                }
                // Initialize
                if (@hasDecl(T, "init")) {
                    const ccore: *const Core = core;
                    return self.init(ccore);
                }
            }
            fn callDeinit(pointer: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "deinit")) {
                    self.deinit();
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
            .v_call_init = gen.callInit,
            .v_call_deinit = gen.callDeinit,
            .v_destroy = gen.destroy,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.v_destroy(self.v_ptr, self.allocator);
    }
    pub fn callInit(self: *@This(), core: *Core) !void {
        if (self.v_call_init) |call| {
            try call(self.v_ptr, core);
        }
    }
    pub fn callDeinit(self: *@This()) void {
        if (self.v_call_deinit) |call| {
            call(self.v_ptr);
        }
    }
};

pub const Core = struct {
    platform: Platform,
    modules: std.ArrayList(Module),
    running: bool = false,
    stages: std.EnumMap(Stage, std.ArrayList(Callable)),

    fn log(
        self: *Core,
        comptime format: []const u8,
        args: anytype,
    ) void {
        if (self.findModule(Logger)) |logger| {
            logger.info(format, args);
        }
    }
    fn registerStageCallback(self: *Core, phase: Stage, callable: Callable) !void {
        var callbacks = self.stages.getPtr(phase) orelse unreachable;
        try callbacks.append(self.platform.allocator, callable);
    }
    fn callStage(self: *Core, phase: Stage) !void {
        const callbacks = self.stages.get(phase) orelse unreachable;
        for (callbacks.items) |callback| {
            try callback.call();
        }
    }

    pub fn init(platform: Platform) !*Core {
        var core = try platform.allocator.create(@This());
        core.platform = platform;
        core.modules = try .initCapacity(platform.allocator, 32);
        core.stages = .{};
        inline for (std.meta.fields(Stage)) |field| {
            core.stages.put(@field(Stage, field.name), .empty);
        }

        // Register required modules
        try core.registerModules(.{Logger});
        try core.registerModules(.{ File, Cart, Config });

        // Mount base file system
        var file = core.findModule(File) orelse unreachable;
        if (core.platform.config.mount) |entryPoint| {
            try file.mount(entryPoint);
        } else {
            try file.mount(".");
        }

        // Load configuration
        var config = core.findModule(Config) orelse unreachable;
        try config.loadINI();

        if (config.sections.window.enable) {
            try core.registerModules(.{
                Window,
            });
        }

        // Register other core modules
        try core.registerModules(.{
            Node,
            Signal,
            Input,
            Transform,
            InputMap,
            SourceFile,
            Script,
            Graphics,
            Texture,
            Mesh,
            StaticMesh,
            Lua,
            GUI,
        });
        errdefer core.deinit();

        // Handle command
        switch (core.platform.config.command) {
            .run => |run| {
                var lua = core.findModule(Lua) orelse unreachable;
                try lua.callEntryPoint(run.script);
                core.running = true;
            },
            .build => |build| {
                var cart = core.findModule(Cart) orelse unreachable;
                var logger = core.findModule(Logger) orelse unreachable;
                try cart.begin(build.path);
                try cart.writeGlob(build.glob);
                logger.info("out {s} ({s})", .{ build.path, build.glob });
            },
        }

        return core;
    }

    pub fn deinit(self: *Core) void {
        // Delete nodes
        if (self.findModule(Node)) |node| {
            node.delete(node.getRoot()) catch {};
        }
        // Call deinit on modules
        var i = self.modules.items.len;
        while (i > 0) : (i -= 1) {
            const module = &self.modules.items[i - 1];
            if (self.platform.config.logModuleInitialization) {
                self.log("deinit module {s}...", .{module.name});
            }
            module.callDeinit();
        }
        // Free callbacks
        var it = self.stages.iterator();
        while (it.next()) |entry| {
            entry.value.deinit(self.platform.allocator);
        }
        // Free modules
        i = self.modules.items.len;
        while (i > 0) : (i -= 1) {
            self.modules.items[i - 1].deinit();
        }
        self.modules.deinit(self.platform.allocator);
        // Free core
        self.platform.allocator.destroy(self);
    }

    pub fn isRunning(self: *const Core) bool {
        return self.running;
    }

    pub fn update(self: *Core) !void {
        if (self.running) {
            try self.callStage(.pre_update);
            try self.callStage(.update);
            try self.callStage(.post_update);
        }
    }

    pub fn pushEvent(self: *Core, event: Platform.Event) void {
        const input = self.findModule(Input) orelse return;
        switch (event) {
            .requestExit => self.running = false,
            else => {},
        }
        input.onEvent(&event);
    }

    pub fn registerModules(self: *Core, comptime mods: anytype) !void {
        const first = self.modules.items.len;
        // Register modules
        inline for (mods) |mod| {
            if (self.platform.config.logModuleInitialization) {
                self.log("register module {s}...", .{@typeName(mod)});
            }
            const module = try self.modules.addOne(self.platform.allocator);
            module.* = try .init(mod, self.platform.allocator);
        }
        // Initialize modules
        for (self.modules.items[first..]) |*module| {
            if (self.platform.config.logModuleInitialization) {
                self.log("init module {s}...", .{module.name});
            }
            try module.callInit(self);
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
