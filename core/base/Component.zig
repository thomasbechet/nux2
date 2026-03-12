const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const Index = u32;
pub const ID = u8;

pub const module_components_field = "components";

pub const ComponentType = struct {
    name: []const u8,
    v_ptr: *anyopaque,
    v_deinit: *const fn (*anyopaque) void,
    v_add: *const fn (*anyopaque, id: nux.ID) anyerror!void,
    v_remove: *const fn (*anyopaque, id: nux.ID) void,
    v_has: *const fn (*anyopaque, id: nux.ID) bool,
    v_load: *const fn (*anyopaque, id: nux.ID, reader: *nux.Reader) anyerror!void,
    v_save: *const fn (*anyopaque, id: nux.ID, writer: *nux.Writer) anyerror!void,
    v_description: *const fn (*anyopaque, id: nux.ID, w: *std.Io.Writer) anyerror!void,
};

pub fn Components(T: type) type {
    return struct {
        id: ID,
        allocator: std.mem.Allocator,
        data: std.ArrayList(union {
            used: struct {
                data: T,
                id: nux.ID,
            },
            free: ?Index,
        }) = .empty,
        bitset: std.DynamicBitSet,
        free_index: ?Index = null,
        node: *nux.Node,

        pub const Iterator = struct {
            components: *Components(T),
            iterator: std.DynamicBitSet.Iterator(.{}),
            fn init(components: *Components(T)) @This() {
                return .{
                    .components = components,
                    .iterator = components.bitset.iterator(.{}),
                };
            }
            pub fn next(self: *@This()) ?struct { data: *T, id: nux.ID } {
                const index = self.iterator.next() orelse return null;
                const entry = &self.components.data.items[index].used;
                return .{
                    .data = &entry.data,
                    .id = entry.id,
                };
            }
        };

        pub const ValuesIterator = struct {
            iterator: Iterator,
            fn init(components: *Components(T)) @This() {
                return .{
                    .iterator = .init(components),
                };
            }
            pub fn next(self: *@This()) ?*T {
                const entry = self.iterator.next() orelse return null;
                return entry.data;
            }
        };

        fn init(allocator: std.mem.Allocator, node: *nux.Node, type_index: ID) !@This() {
            return .{
                .allocator = allocator,
                .node = node,
                .data = .empty,
                .bitset = try .initEmpty(allocator, 128),
                .id = type_index,
            };
        }
        fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
            self.bitset.deinit();
        }

        fn initComponent(self: *@This(), data: *T) !void {
            if (@hasDecl(T, "init")) {
                data.* = try T.init(@fieldParentPtr(module_components_field, self));
            } else {
                data.* = .{};
            }
        }
        fn deinitComponent(self: *@This(), data: *T) void {
            if (@hasDecl(T, "deinit")) {
                data.deinit(@fieldParentPtr(module_components_field, self));
            }
        }
        fn addUninitialized(self: *@This(), id: nux.ID) !*T {
            // Check node entry
            const entry = try self.node.getEntry(id);
            var index: Index = undefined;
            if (entry.components[self.id]) |previous_index| { // Reuse index
                index = previous_index;
                // Deinit previous component
                const data = &self.data.items[@intCast(index)].used.data;
                self.deinitComponent(data);
            } else {
                if (self.free_index) |free| { // Free index
                    index = free;
                    self.free_index = self.data.items[@intCast(free)].free;
                } else { // New index
                    index = @intCast(self.data.items.len);
                    try self.data.append(self.allocator, .{ .used = .{
                        .data = undefined,
                        .id = id,
                    } });
                }
            }
            self.bitset.set(@intCast(index));
            entry.components[@intCast(self.id)] = index;
            return &self.data.items[@intCast(index)].used.data;
        }

        pub fn addPtr(self: *@This(), id: nux.ID) !*T {
            const data = try self.addUninitialized(id);
            try self.initComponent(data);
            return data;
        }
        pub fn add(self: *@This(), id: nux.ID) !void {
            _ = try self.addPtr(id);
        }
        pub fn addWith(self: *@This(), id: nux.ID, data: T) !void {
            const component = try self.addUninitialized(id);
            component.* = data;
        }
        pub fn remove(self: *@This(), id: nux.ID) void {
            const entry = self.node.getEntry(id) catch return;
            const index = entry.components[self.id] orelse return;
            // Deinit component
            const data = &self.data.items[@intCast(index)].used.data;
            self.deinitComponent(data);
            // Remove from pool
            self.data.items[@intCast(index)] = .{ .free = self.free_index };
            self.free_index = index;
            self.bitset.unset(@intCast(index));
            entry.components[self.id] = null;
        }
        pub fn has(self: *@This(), id: nux.ID) bool {
            return self.getOptional(id) != null;
        }
        pub fn iterator(self: *@This()) Iterator {
            return .init(self);
        }
        pub fn values(self: *@This()) ValuesIterator {
            return .init(self);
        }
        pub fn getOptional(self: *@This(), id: nux.ID) ?*T {
            const entry = self.node.getEntry(id) catch return null;
            const index = entry.components[@intCast(self.id)] orelse return null;
            return &self.data.items[index].used.data;
        }
        pub fn get(self: *@This(), id: nux.ID) !*T {
            return self.getOptional(id) orelse return error.ComponentNotFound;
        }
        pub fn load(self: *@This(), id: nux.ID, reader: *nux.Reader) !void {
            const data = try self.addUninitialized(id);
            if (@hasDecl(T, "load")) {
                data.* = try T.load(@fieldParentPtr(module_components_field, self), reader);
            }
        }
        pub fn save(self: *@This(), id: nux.ID, writer: *nux.Writer) !void {
            const data = try self.get(id);
            if (@hasDecl(T, "save")) {
                try data.save(@fieldParentPtr(module_components_field, self), writer);
            }
        }
        pub fn description(self: *@This(), id: nux.ID, writer: *std.Io.Writer) !void {
            const data = try self.get(id);
            if (@hasDecl(T, "description")) {
                try data.description(@fieldParentPtr(module_components_field, self), writer);
            }
        }
    };
}

allocator: std.mem.Allocator,
component_types: std.ArrayList(ComponentType),
file: *nux.File,
node: *nux.Node,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.component_types = try .initCapacity(self.allocator, 64);
}
pub fn deinit(self: *Self) void {
    for (self.component_types.items) |typ| {
        typ.v_deinit(typ.v_ptr);
    }
    self.component_types.deinit(self.allocator);
}

pub fn find(self: *Self, name: []const u8) !*ComponentType {
    for (self.component_types.items) |*typ| {
        if (std.mem.eql(u8, typ.name, name)) {
            return typ;
        }
    }
    return error.ComponentTypeNotFound;
}
pub fn get(self: *Self, component: ID) !*ComponentType {
    if (component >= self.component_types.items.len) {
        return error.InvalidComponentID;
    }
    return &self.component_types.items[component];
}
pub fn registerModule(self: *Self, module: anytype) !void {
    const T = @typeInfo(@TypeOf(module)).pointer.child;
    if (@hasField(T, module_components_field)) {

        // Init pool
        const component_id: ID = @intCast(self.component_types.items.len);
        @field(module, module_components_field) = try .init(self.allocator, self.node, component_id);

        // Create vtable
        const gen = struct {
            fn deinit(pointer: *anyopaque) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                @field(mod, module_components_field).deinit();
            }
            fn add(pointer: *anyopaque, id: nux.ID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                _ = try @field(mod, module_components_field).add(id);
            }
            fn remove(pointer: *anyopaque, id: nux.ID) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                @field(mod, module_components_field).remove(id);
            }
            fn has(pointer: *anyopaque, id: nux.ID) bool {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return @field(mod, module_components_field).has(id);
            }
            fn load(pointer: *anyopaque, id: nux.ID, reader: *nux.Reader) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                try @field(mod, module_components_field).load(id, reader);
            }
            fn save(pointer: *anyopaque, id: nux.ID, writer: *nux.Writer) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                try @field(mod, module_components_field).save(id, writer);
            }
            fn description(pointer: *anyopaque, id: nux.ID, writer: *std.Io.Writer) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                try @field(mod, module_components_field).description(id, writer);
            }
        };

        // Register type
        var it = std.mem.splitBackwardsScalar(u8, @typeName(T), '.');
        const name = it.first();
        (try self.component_types.addOne(self.allocator)).* = .{
            .name = name,
            .v_ptr = module,
            .v_deinit = gen.deinit,
            .v_add = gen.add,
            .v_remove = gen.remove,
            .v_has = gen.has,
            .v_save = gen.save,
            .v_load = gen.load,
            .v_description = gen.description,
        };
    }
}
