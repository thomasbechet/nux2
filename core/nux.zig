const std = @import("std");

const modules = @import("modules.zig");
pub const Logger = @import("base/Logger.zig");
pub const Config = @import("base/Config.zig");
pub const Collection = @import("base/Collection.zig");
pub const Module = @import("base/Module.zig");
pub const Node = @import("base/Node.zig");
pub const Component = @import("base/Component.zig");
pub const Function = @import("base/Function.zig");
pub const Property = @import("base/Property.zig");
pub const Signal = @import("base/Signal.zig");
pub const File = @import("base/File.zig");
pub const Cart = @import("base/Cart.zig");
pub const Transform = @import("base/Transform.zig");
pub const DataFrame = @import("base/DataFrame.zig");
pub const Input = @import("input/Input.zig");
pub const InputMap = @import("input/InputMap.zig");
pub const Lua = @import("lua/Lua.zig");
pub const Graphics = @import("graphics/Graphics.zig");
pub const Texture = @import("graphics/Texture.zig");
pub const Mesh = @import("graphics/Mesh.zig");
pub const Material = @import("graphics/Material.zig");
pub const StaticMesh = @import("graphics/StaticMesh.zig");
pub const Camera = @import("graphics/Camera.zig");
pub const Widget = @import("ui/Widget.zig");
pub const Viewport = @import("ui/Viewport.zig");
pub const Label = @import("ui/Label.zig");
pub const Button = @import("ui/Button.zig");
pub const Font = @import("ui/Font.zig");
pub const Window = @import("graphics/Window.zig");
pub const Vertex = @import("graphics/Vertex.zig");
pub const GPU = @import("graphics/GPU.zig");
pub const Rasterizer = @import("graphics/Rasterizer.zig");
pub const Gltf = @import("graphics/Gltf.zig");

pub const ID = Node.ID;
pub const ModuleID = Module.ID;
pub const FunctionID = Function.ID;
pub const Components = Component.Components;
pub const Writer = Node.Writer;
pub const Reader = Node.Reader;
pub const vec = @import("math/vec.zig");
pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;
pub const Vec2i = vec.Vec2i;
pub const Vec3i = vec.Vec3i;
pub const Vec4i = vec.Vec4i;
pub const quat = @import("math/quat.zig");
pub const Quat = quat.Quat;
pub const box = @import("math/box.zig");
pub const Box2 = box.Box2;
pub const Box3 = box.Box3;
pub const Box2i = box.Box2i;
pub const Box3i = box.Box3i;
pub const Color = @import("math/color.zig").Color;
pub const SpanAllocator = @import("utils/SpanAllocator.zig");
pub const Callable = @import("utils/Callable.zig");
pub const Deque = @import("utils/Deque.zig").Deque; // TODO: wait 0.16.0 for std
pub const ObjectPool = @import("utils/ObjectPool.zig").ObjectPool;

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
            run,
            build: struct {
                path: []const u8 = "cart.bin",
                glob: []const u8 = "*",
            },
        } = .run,
        mount: ?[]const u8 = null,
    };
    allocator: Platform.Allocator = std.heap.page_allocator,
    logger: Platform.Logger = .{},
    file: Platform.File = .{},
    window: Platform.Window = .{},
    gpu: Platform.GPU = .{},

    config: Platform.Config = .{},
};

const Stage = enum {
    start,
    pre_update,
    update,
    post_update,
    render,
    stop,
};

pub const Core = struct {
    platform: Platform,
    module: *Module,
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
        core.stages = .{};
        inline for (std.meta.fields(Stage)) |field| {
            core.stages.put(@field(Stage, field.name), .empty);
        }
        errdefer core.deinit();

        // Create modules
        inline for (@typeInfo(modules).@"struct".decls) |mod| {
            const ModuleInfo = @field(modules, mod.name);
            try core.module.register(ModuleInfo);
        }

        // Start sequence
        core.module.initAll();
        core.module.startAll();

        // Handle command
        switch (core.platform.config.command) {
            .run => {
                var lua = core.findModule(Lua) orelse unreachable;
                _ = try lua.loadModule("init.lua");
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

        // Stop sequence
        self.module.stopAll();
        self.module.deinitAll();
        self.module.deinit();

        // Deinit stages
        var it = self.stages.iterator();
        while (it.next()) |entry| {
            entry.value.deinit(self.platform.allocator);
        }

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
            try self.callStage(.render);
        }
    }

    pub fn pushEvent(self: *Core, event: Platform.Event) void {
        const input = self.module.getByType(Input);
        const window = self.module.getByType(Window);
        switch (event) {
            .requestExit => self.running = false,
            else => {},
        }
        input.onEvent(&event);
        window.onEvent(&event);
    }
};
