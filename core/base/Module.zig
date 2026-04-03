const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

fn typeHash(comptime T: type) u32 {
    return std.hash.Fnv1a_32.hash(@typeName(T));
}

pub const ID = usize;

pub const State = enum(u32) {
    created,
    initialized,
    started,
};

pub const ModuleVTable = struct {
    init: *const fn (*anyopaque, core: *nux.Core) anyerror!void,
    deinit: *const fn (*anyopaque) void,
    start: *const fn (*anyopaque) anyerror!void,
    stop: *const fn (*anyopaque) void,
    destroy: *const fn (*anyopaque, std.mem.Allocator) void,
};

pub const ComponentVTable = struct {
    init: *const fn (*anyopaque) anyerror!void,
    deinit: *const fn (*anyopaque) void,
    add: *const fn (*anyopaque, id: nux.ID) anyerror!void,
    remove: *const fn (*anyopaque, id: nux.ID) void,
    has: *const fn (*anyopaque, id: nux.ID) bool,
    load: *const fn (*anyopaque, id: nux.ID, reader: *nux.Reader) anyerror!void,
    save: *const fn (*anyopaque, id: nux.ID, writer: *nux.Writer) anyerror!void,
    description: *const fn (*anyopaque, id: nux.ID, w: *std.Io.Writer) anyerror!void,
};

pub const Module = struct {
    name: []const u8,
    type_hash: u32,
    state: State = .created,
    v_ptr: *anyopaque,
    v_module: ModuleVTable,
    v_component: ?ComponentVTable = null,
    functions: std.StringHashMap(nux.Function.Function),
    enums: std.StringHashMap(u64),

    pub fn destroy(self: *@This()) void {
        if (self.state == .created) {
            self.v_module.destroy(self.v_ptr, self.allocator);
            self.functions.deinit();
            self.enums.deinit();
        }
    }
    pub fn init(self: *@This(), core: *nux.Core) !void {
        std.log.info("INIT {s}", .{self.name});
        std.debug.assert(self.state == .created);
        if (self.v_component) |v_component| {
            try v_component.init(self.v_ptr);
        }
        try self.v_module.init(self.v_ptr, core);
        self.state = .initialized;
    }
    pub fn deinit(self: *@This()) void {
        std.log.info("DEINIT {s}", .{self.name});
        if (self.state == .initialized) {
            self.v_module.deinit(self.v_ptr);
            if (self.v_component) |v_component| {
                try v_component.deinit(self.v_ptr);
            }
            self.state = .created;
        }
    }
    pub fn start(self: *@This()) !void {
        std.log.info("START {s}", .{self.name});
        std.debug.assert(self.state == .initialized);
        try self.v_module.start(self.v_ptr);
        self.state = .started;
    }
    pub fn stop(self: *@This()) void {
        std.log.info("STOP {s}", .{self.name});
        if (self.state == .started) {
            try self.v_module.stop(self.v_ptr);
            self.state = .initialized;
        }
    }
};

allocator: std.mem.Allocator,
modules: std.ArrayList(Module),
names: std.StringHashMap(ID),
hashes: std.AutoHashMap(u32, ID),

pub fn init(self: *Self, core: *nux.Core) !Self {
    self.allocator = core.platform.allocator;
    self.modules = .empty;
    self.names = .init(self.allocator);

    // Create base modules
}
pub fn deinit(self: *Self) void {
    for (self.modules.items) |*module| {
        module.destroy();
    }
    self.modules.deinit(self.allocator);
    self.names.deinit();
}

pub fn register(self: *Self, comptime ModuleInfo: anytype) !void {
    const T = @field(ModuleInfo, "module");
    const module_name = @field(ModuleInfo, "name");
    const has_components = @hasField(T, nux.Component.module_components_field);
    const module = try self.modules.addOne(self.allocator);
    module.name = module_name;
    module.type_hash = typeHash(T);
    module.v_ptr = try self.allocator.create(T);
    module.functions = .init(self.allocator);
    module.enums = .init(self.allocator);

    std.log.info("REGISTER {s}", .{module_name});

    // Register module
    const module_gen = struct {
        fn init(pointer: *anyopaque, core: *nux.Core) anyerror!void {
            const mod: *T = @ptrCast(@alignCast(pointer));

            // Dependency injection
            inline for (@typeInfo(T).@"struct".fields) |field| {
                switch (@typeInfo(field.type)) {
                    .pointer => |info| {
                        if (info.child != u8) {
                            if (core.module.findByType(info.child)) |dependency| {
                                @field(mod, field.name) = dependency;
                            }
                        }
                    },
                    else => {},
                }
            }

            // Register callbacks
            if (@hasDecl(T, "onPreUpdate")) {
                try core.registerStageCallback(.pre_update, .wrap(T, T.onPreUpdate, mod));
            }
            if (@hasDecl(T, "onUpdate")) {
                try core.registerStageCallback(.update, .wrap(T, T.onUpdate, mod));
            }
            if (@hasDecl(T, "onPostUpdate")) {
                try core.registerStageCallback(.post_update, .wrap(T, T.onPostUpdate, mod));
            }
            if (@hasDecl(T, "onRender")) {
                try core.registerStageCallback(.render, .wrap(T, T.onRender, mod));
            }
            if (@hasDecl(T, "init")) {
                const ccore: *const nux.Core = core;
                try mod.init(ccore);
            }
        }
        fn deinit(pointer: *anyopaque) void {
            const mod: *T = @ptrCast(@alignCast(pointer));
            if (@hasDecl(T, "deinit")) {
                mod.deinit();
            }
            if (has_components) {
                @field(mod, nux.Component.module_components_field).deinit();
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
                node: *nux.Node,
                allocator: *std.mem.Allocator,
            ) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                const component_id: ID = @intCast(self.component_types.items.len);
                @field(mod, nux.Component.module_components_field) = try .init(
                    allocator,
                    node,
                    component_id,
                );
            }
            fn deinit(pointer: *anyopaque) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                @field(mod, nux.Component.module_components_field).deinit();
            }
            fn add(pointer: *anyopaque, id: nux.ID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                _ = try @field(mod, nux.Component.module_components_field).add(id);
            }
            fn remove(pointer: *anyopaque, id: nux.ID) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                @field(mod, nux.Component.module_components_field).remove(id);
            }
            fn has(pointer: *anyopaque, id: nux.ID) bool {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return @field(mod, nux.Component.module_components_field).has(id);
            }
            fn load(pointer: *anyopaque, id: nux.ID, reader: *nux.Reader) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                try @field(mod, nux.Component.module_components_field).load(id, reader);
            }
            fn save(pointer: *anyopaque, id: nux.ID, writer: *nux.Writer) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                try @field(mod, nux.Component.module_components_field).save(id, writer);
            }
            fn description(pointer: *anyopaque, id: nux.ID, writer: *std.Io.Writer) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                try @field(mod, nux.Component.module_components_field).description(id, writer);
            }
        };
        module.v_component = .{
            .add = component_gen.add,
            .remove = component_gen.remove,
            .has = component_gen.has,
            .save = component_gen.save,
            .load = component_gen.load,
            .description = component_gen.description,
        };
    }

    // Register functions
    const Functions = @field(ModuleInfo, "Functions");
    inline for (@typeInfo(Functions).@"struct".decls) |func_decl| {
        const FunctionInfo = @field(Functions, func_decl.name);
        const FunctionType = @field(FunctionInfo, "function");
        const name = @field(FunctionInfo, "name");
        try module.functions.put(name, .wrap(
            T,
            FunctionType,
            @ptrCast(@alignCast(module.v_ptr)),
        ));
    }

    // Register enums
    const Enums = @field(ModuleInfo, "Enums");
    inline for (@typeInfo(Enums).@"struct".decls) |enum_decl| {
        const EnumInfo = @field(Enums, enum_decl.name);
        const EnumValues = @field(EnumInfo, "Values");
        inline for (@typeInfo(EnumValues).@"struct".decls) |value_decl| {
            const EnumValue = @field(EnumValues, value_decl.name);
            const value = @field(EnumValue, "value");
            const name = @field(EnumValue, "name");
            if (EnumInfo.is_bitfield) {
                try module.enums.put(name, @as(u32, @bitCast(value)));
            } else {
                try module.enums.put(name, @intFromEnum(value));
            }
        }
    }
}
pub fn initAll(self: *Self) !void {
    for (self.modules.items) |*module| {
        try module.init();
    }
}
pub fn startAll(self: *Self) !void {
    for (self.modules.items) |*module| {
        try module.start();
    }
}
pub fn stopAll(self: *Self) void {
    for (self.modules.items) |*module| {
        module.stop();
    }
}
pub fn deinitAll(self: *Self) void {
    for (self.modules.items) |*module| {
        module.deinit();
    }
}

pub fn getByType(self: *Self, comptime T: type) *T {
    for (self.modules.items) |*module| {
        if (std.mem.eql(u8, @typeName(T), module.name)) {
            return @ptrCast(@alignCast(module.v_ptr));
        }
    }
    unreachable;
}

pub fn find(self: *Self, name: []const u8) ?ID {
    return self.names.get(name);
}
pub fn findByType(self: *Self, comptime T: type) ?*T {
    const hash = typeHash(T);
    const id = self.hashes.get(hash) orelse return null;
    return &self.modules.items[id];
}
