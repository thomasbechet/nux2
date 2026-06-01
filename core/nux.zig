const std = @import("std");

const modules = @import("modules.zig");
pub const Registry = @import("base/Registry.zig");
pub const Logger = @import("base/Logger.zig");
pub const Config = @import("base/Config.zig");
pub const Prefab = @import("base/Prefab.zig");
pub const Module = @import("base/Module.zig");
pub const Node = @import("base/Node.zig");
pub const Component = @import("base/Component.zig");
pub const Primitive = @import("base/Primitive.zig");
pub const Function = @import("base/Function.zig");
pub const Enum = @import("base/Enum.zig");
pub const Property = @import("base/Property.zig");
pub const Event = @import("base/Event.zig");
pub const File = @import("base/File.zig");
pub const Cart = @import("base/Cart.zig");
pub const Transform = @import("base/Transform.zig");
pub const DataFrame = @import("base/DataFrame.zig");
pub const System = @import("base/System.zig");
pub const Input = @import("input/Input.zig");
pub const InputMap = @import("input/InputMap.zig");
pub const Lua = @import("lua/Lua.zig");
pub const Graphics = @import("graphics/Graphics.zig");
pub const Texture = @import("graphics/Texture.zig");
pub const Font = @import("graphics/Font.zig");
pub const Mesh = @import("graphics/Mesh.zig");
pub const Material = @import("graphics/Material.zig");
pub const StaticMesh = @import("graphics/StaticMesh.zig");
pub const Camera = @import("graphics/Camera.zig");
pub const Viewport = @import("graphics/Viewport.zig");
pub const Widget = @import("ui/Widget.zig");
pub const StyleSheet = @import("ui/StyleSheet.zig");
pub const Label = @import("ui/Label.zig");
pub const Button = @import("ui/Button.zig");
pub const Window = @import("graphics/Window.zig");
pub const Vertex = @import("graphics/Vertex.zig");
pub const GPU = @import("graphics/GPU.zig");
pub const Rasterizer = @import("graphics/Rasterizer.zig");
pub const Gltf = @import("graphics/Gltf.zig");

pub const ID = Node.ID;
pub const ModuleID = Module.ID;
pub const FunctionID = Function.ID;
pub const EnumID = Enum.ID;
pub const PropertyID = Property.ID;
pub const SignalID = Event.SignalID;
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
pub const mat = @import("math/mat.zig");
pub const Mat3 = mat.Mat3;
pub const Mat4 = mat.Mat4;
pub const Color = @import("math/color.zig").Color;
pub const SpanAllocator = @import("utils/SpanAllocator.zig");
pub const Callable = @import("utils/Callable.zig");
pub const Deque = @import("utils/Deque.zig").Deque; // TODO: wait 0.16.0 for std
pub const ObjectPool = @import("utils/ObjectPool.zig").ObjectPool;
pub const hash = @import("utils/hash.zig");

pub const Platform = struct {
    pub const Config = struct {
        logModules: bool = false, // Log modules
        headless: bool = false, // Disable window module
        build: bool = false, // Build a cartridge
        glob: []const u8 = "*", // Glob for cartridge building
        outpout: []const u8 = "cart.bin", // Cartridge output for building
        mount: []const u8 = ".", // Entrypoint
    };

    pub const System = @import("platform/System.zig");
    pub const Logger = @import("platform/Logger.zig");
    pub const Input = @import("platform/Input.zig");
    pub const Window = @import("platform/Window.zig");
    pub const File = @import("platform/File.zig");
    pub const GPU = @import("platform/GPU.zig");
    pub const Event = union(enum) {
        inputValueChanged: Platform.Input.InputValueChanged,
        windowResized: Platform.Window.WindowResized,
        requestExit,
    };

    config: Platform.Config = .{},

    allocator: std.mem.Allocator = std.heap.page_allocator,
    system: Platform.System = .{},
    logger: Platform.Logger = .{},
    file: Platform.File = .{},
    window: Platform.Window = .{},
    gpu: Platform.GPU = .{},
};

pub const Core = struct {
    platform: Platform,
    registry: Registry,
    running: bool = false,
    modules: std.ArrayList(Module.Module),

    fn log(
        self: *Core,
        comptime format: []const u8,
        args: anytype,
    ) void {
        if (self.platform.config.logModules) {
            if (self.getModuleByType(Logger)) |logger| {
                logger.info(format, args);
            }
        }
    }
    fn register(self: *Core, comptime ModuleInfo: anytype) !void {
        const T = @field(ModuleInfo, "module");
        const module_name = @field(ModuleInfo, "name");
        const has_components = @hasField(T, Component.module_components_field);
        const module = try self.modules.addOne(self.platform.allocator);
        module.name = module_name;
        module.type_hash = hash.fromType(T);
        module.v_ptr = try self.platform.allocator.create(T);
        module.functions = .empty;
        module.enums = .empty;
        module.properties = .empty;
        module.state = .created;
        module.v_component = null;

        // Register module
        const module_gen = struct {
            fn init(pointer: *anyopaque, core: *Core) anyerror!void {
                const mod: *T = @ptrCast(@alignCast(pointer));

                // Dependency injection
                inline for (@typeInfo(T).@"struct".fields) |field| {
                    switch (@typeInfo(field.type)) {
                        .pointer => |info| {
                            if (info.child == Core) {
                                @field(mod, field.name) = core;
                            } else if (info.child != u8) {
                                if (core.getModuleByType(info.child)) |dependency| {
                                    @field(mod, field.name) = dependency;
                                }
                            }
                        },
                        else => {},
                    }
                }

                // Register callbacks
                if (core.getModuleByType(Event)) |event| {
                    if (@hasDecl(T, "onPreUpdate")) {
                        try event.bind(event.getStageSignal(.pre_update), .wrap(T, T.onPreUpdate, mod));
                    }
                    if (@hasDecl(T, "onUpdate")) {
                        try event.bind(event.getStageSignal(.update), .wrap(T, T.onUpdate, mod));
                    }
                    if (@hasDecl(T, "onPostUpdate")) {
                        try event.bind(event.getStageSignal(.post_update), .wrap(T, T.onPostUpdate, mod));
                    }
                    if (@hasDecl(T, "onRender")) {
                        try event.bind(event.getStageSignal(.render), .wrap(T, T.onRender, mod));
                    }
                }

                // Initialize module
                if (@hasDecl(T, "init")) {
                    const ccore: *const Core = core;
                    try mod.init(ccore);
                }
            }
            fn deinit(pointer: *anyopaque) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "deinit")) {
                    mod.deinit();
                }
            }
            fn start(pointer: *anyopaque) !void {
                if (@hasDecl(T, "onStart")) {
                    const mod: *T = @ptrCast(@alignCast(pointer));
                    try mod.onStart();
                }
            }
            fn stop(pointer: *anyopaque) void {
                if (@hasDecl(T, "onStop")) {
                    const mod: *T = @ptrCast(@alignCast(pointer));
                    mod.onStop();
                }
            }
            fn destroy(
                pointer: *anyopaque,
                alloc: std.mem.Allocator,
            ) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                alloc.destroy(mod);
            }
        };
        module.v_module.init = module_gen.init;
        module.v_module.deinit = module_gen.deinit;
        module.v_module.start = module_gen.start;
        module.v_module.stop = module_gen.stop;
        module.v_module.destroy = module_gen.destroy;

        // Register components
        if (has_components) {
            const component_gen = struct {
                fn init(
                    pointer: *anyopaque,
                    node: *Node,
                    allocator: std.mem.Allocator,
                    module_id: ModuleID,
                ) !void {
                    const mod: *T = @ptrCast(@alignCast(pointer));
                    @field(mod, Component.module_components_field) = try .init(
                        allocator,
                        node,
                        module_id,
                    );
                }
                fn deinit(pointer: *anyopaque) void {
                    const mod: *T = @ptrCast(@alignCast(pointer));
                    @field(mod, Component.module_components_field).deinit();
                }
                fn add(pointer: *anyopaque, id: ID) !void {
                    const mod: *T = @ptrCast(@alignCast(pointer));
                    _ = try @field(mod, Component.module_components_field).add(id);
                }
                fn remove(pointer: *anyopaque, id: ID) void {
                    const mod: *T = @ptrCast(@alignCast(pointer));
                    @field(mod, Component.module_components_field).remove(id);
                }
                fn has(pointer: *anyopaque, id: ID) bool {
                    const mod: *T = @ptrCast(@alignCast(pointer));
                    return @field(mod, Component.module_components_field).has(id);
                }
                fn load(pointer: *anyopaque, id: ID, reader: *Reader) !void {
                    const mod: *T = @ptrCast(@alignCast(pointer));
                    try @field(mod, Component.module_components_field).load(id, reader);
                }
                fn save(pointer: *anyopaque, id: ID, writer: *Writer) !void {
                    const mod: *T = @ptrCast(@alignCast(pointer));
                    try @field(mod, Component.module_components_field).save(id, writer);
                }
            };
            module.v_component = .{
                .init = component_gen.init,
                .deinit = component_gen.deinit,
                .add = component_gen.add,
                .remove = component_gen.remove,
                .has = component_gen.has,
                .save = component_gen.save,
                .load = component_gen.load,
            };
        }

        // Register enums
        const Enums = ModuleInfo.Enums;
        inline for (@typeInfo(Enums).@"struct".decls) |enum_decl| {
            const EnumInfo = @field(Enums, enum_decl.name);
            const values = comptime Enum.getValues(EnumInfo);
            if (EnumInfo.is_bitfield) {
                try module.enums.append(self.platform.allocator, .{
                    .name = EnumInfo.name,
                    .values = values,
                });
            } else {
                try module.enums.append(self.platform.allocator, .{
                    .name = EnumInfo.name,
                    .values = values,
                });
            }
        }

        // Register functions
        const Functions = @field(ModuleInfo, "Functions");
        inline for (@typeInfo(Functions).@"struct".decls) |func_decl| {
            const FunctionInfo = @field(Functions, func_decl.name);
            const FunctionMethod = @field(FunctionInfo, "function");
            const name = @field(FunctionInfo, "name");
            const params = comptime Function.getParameters(FunctionInfo.Params);
            try module.functions.append(self.platform.allocator, .wrap(
                name,
                T,
                FunctionMethod,
                params,
                @ptrCast(@alignCast(module.v_ptr)),
            ));
        }

        // // Register properties
        // const Properties = @field(ModuleInfo, "Properties");
        // inline for (@typeInfo(Properties).@"struct".decls) |prop_decl| {
        //     const PropertyInfo = @field(Properties, prop_decl.name);
        //     const name = @field(PropertyInfo, "name");
        //     const getter = @field(PropertyInfo, "getter");
        //     const setter = @field(PropertyInfo, "setter");
        //     const EV = @typeInfo(@TypeOf(getter)).@"fn".return_type.?;
        //     const V = @typeInfo(EV).error_union.payload;
        //     try module.properties.append(
        //         self.platform.allocator,
        //         .init(
        //             T,
        //             V,
        //             name,
        //             getter,
        //             setter,
        //         ),
        //     );
        // }
    }

    pub fn init(platform: Platform) !*Core {
        var core = try platform.allocator.create(@This());
        core.platform = platform;
        core.registry = try .init(platform.allocator);
        core.modules = .empty;
        errdefer core.deinit();

        // Create modules
        inline for (@typeInfo(modules).@"struct".decls) |mod| {
            core.log("create {s}...", .{mod.name});
            const ModuleInfo = @field(modules, mod.name);
            try core.register(ModuleInfo);
        }

        // Start sequence
        for (core.modules.items, 0..) |*module, index| {
            core.log("init {s}...", .{module.name});
            module.init(core, .{ .index = index }) catch |err| {
                core.log("Failed to init {s}: {s}", .{ module.name, @errorName(err) });
                return error.ModuleInit;
            };
        }
        for (core.modules.items) |*module| {
            core.log("starting {s}...", .{module.name});
            try module.start();
        }

        // Handle command
        if (core.platform.config.build) {
            var cart = core.getModuleByType(Cart) orelse unreachable;
            var logger = core.getModuleByType(Logger) orelse unreachable;
            try cart.begin(core.platform.config.outpout);
            try cart.writeGlob(core.platform.config.glob);
            logger.info("out {s} ({s})", .{
                core.platform.config.outpout,
                core.platform.config.glob,
            });
        } else {
            var lua = core.getModuleByType(Lua) orelse unreachable;
            _ = try lua.loadModule("init.lua");
            core.running = true;
        }

        return core;
    }

    pub fn deinit(self: *Core) void {

        // Stop sequence (in reverse)
        var i: usize = self.modules.items.len;
        while (i > 0) {
            i -= 1;
            const module = &self.modules.items[i];
            self.log("stopping {s}...", .{module.name});
            module.stop();
        }
        i = self.modules.items.len;
        while (i > 0) {
            i -= 1;
            const module = &self.modules.items[i];
            self.log("deinit {s}...", .{module.name});
            module.deinit();
        }

        // Destroy modules
        for (self.modules.items) |*module| {
            module.destroy(self.platform.allocator);
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
            const event = self.getModuleByType(Event) orelse unreachable;
            try event.update();

            if (self.platform.system.vtable.memory_usage(self.platform.system.ptr)) |usage| {
                self.log("RAM usage: {d:.2} MB", .{usage});
            }
        }
    }

    pub fn pushEvent(self: *Core, event: Platform.Event) void {
        const input = self.getModuleByType(Input) orelse unreachable;
        const window = self.getModuleByType(Window) orelse unreachable;
        switch (event) {
            .requestExit => self.running = false,
            else => {},
        }
        input.onEvent(&event);
        window.onEvent(&event);
    }

    pub fn getModule(self: *Core, id: ModuleID) !*Module.Module {
        return self.getModuleByIndex(id.index);
    }

    pub fn getModuleByIndex(self: *Core, index: usize) !*Module.Module {
        if (index >= self.modules.items.len) {
            return error.InvalidModuleID;
        }
        return &self.modules.items[index];
    }

    pub fn getModuleByType(self: *Core, comptime T: type) ?*T {
        const type_hash = hash.fromType(T);
        for (self.modules.items) |*module| {
            if (module.type_hash == type_hash) {
                return @ptrCast(@alignCast(module.v_ptr));
            }
        }
        return null;
    }
};
