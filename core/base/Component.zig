const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const Index = u32;
pub const module_components_field = "components";

pub const VTable = struct {
    init: *const fn (
        pointer: *anyopaque,
        node: *nux.Node,
        allocator: std.mem.Allocator,
        module_id: nux.ModuleID,
    ) anyerror!void,
    deinit: *const fn (*anyopaque) void,
    add: *const fn (*anyopaque, id: nux.ID) anyerror!void,
    remove: *const fn (*anyopaque, id: nux.ID) void,
    has: *const fn (*anyopaque, id: nux.ID) bool,
    load: *const fn (*anyopaque, id: nux.ID, reader: *nux.Reader) anyerror!void,
    save: *const fn (*anyopaque, id: nux.ID, writer: *nux.Writer) anyerror!void,
    description: *const fn (*anyopaque, id: nux.ID, w: *std.Io.Writer) anyerror!void,
};

pub fn Components(T: type) type {
    return struct {
        const Entry = struct {
            data: T,
            id: nux.ID,
        };

        id: nux.ModuleID,
        allocator: std.mem.Allocator,
        data: nux.ObjectPool(Entry),
        bitset: std.DynamicBitSet,
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
            pub fn next(self: *@This()) ?struct { component: *T, id: nux.ID } {
                const index = self.iterator.next() orelse return null;
                const component = self.components.data.get(index);
                return .{
                    .component = &component.data,
                    .id = component.id,
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
                return entry.component;
            }
        };

        pub fn init(
            allocator: std.mem.Allocator,
            node: *nux.Node,
            module_id: nux.ModuleID,
        ) !@This() {
            return .{
                .allocator = allocator,
                .node = node,
                .data = .init(allocator),
                .bitset = try .initEmpty(allocator, 128),
                .id = module_id,
            };
        }
        pub fn deinit(self: *@This()) void {
            self.data.deinit();
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
                const data = &self.data.get(previous_index).data;
                // Deinit previous component
                self.deinitComponent(data);
            } else {
                index = @intCast(try self.data.add(.{
                    .data = undefined,
                    .id = id,
                }));
            }
            // Resize bitset
            if (index >= self.bitset.unmanaged.bit_length) {
                try self.bitset.resize((index + 1) * 2, false);
            }
            self.bitset.set(@intCast(index));
            entry.components[@intCast(self.id)] = index;
            return &self.data.get(index).data;
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
            const data = &self.data.get(index).data;
            self.deinitComponent(data);
            // Remove from pool
            self.data.remove(index);
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
            return &self.data.get(index).data;
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

node: *nux.Node,
core: *nux.Core,

pub fn getModule(self: *Self, id: nux.ModuleID) !*nux.Module.Module {
    const module = try self.core.getModule(id);
    if (module.v_component != null) {
        return module;
    }
    return error.NotAComponentModule;
}
pub fn add(self: *Self, id: nux.ID, comp: nux.ModuleID) !void {
    const module = try self.getModule(comp);
    try module.v_component.?.add(module.v_ptr, id);
}
pub fn remove(self: *Self, id: nux.ID, comp: nux.ModuleID) !void {
    const module = try self.getModule(comp);
    module.v_component.?.remove(module.v_ptr, id);
}
