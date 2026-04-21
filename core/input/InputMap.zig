const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Component = struct {
    const Entry = struct {
        name: []const u8,
        index: usize,
        mapping: ?nux.Input.Input,
        sensivity: f32 = 1,
    };

    entries: std.ArrayList(Entry),
    lookup: std.StringHashMap(usize),
    sensivity: f32,

    pub fn init(mod: *Self) !Component {
        return .{
            .entries = .empty,
            .lookup = .init(mod.allocator),
            .sensivity = 1,
        };
    }
    pub fn deinit(self: *Component, mod: *Self) void {
        for (self.entries.items) |entry| {
            mod.allocator.free(entry.name);
        }
        self.entries.deinit(mod.allocator);
        self.lookup.deinit();
    }

    pub fn put(
        self: *Component,
        mod: *Self,
        name: []const u8,
    ) !*Entry {
        if (self.get(name)) |entry| {
            return entry;
        }
        const index = self.entries.items.len;
        const entry = try self.entries.addOne(mod.allocator);
        entry.name = try mod.allocator.dupe(u8, name);
        entry.index = index;
        try self.lookup.put(entry.name, index);
        return entry;
    }

    pub fn get(self: *Component, name: []const u8) ?*Entry {
        if (self.lookup.get(name)) |index| {
            return &self.entries.items[index];
        }
        return null;
    }
};

allocator: std.mem.Allocator,
components: nux.Components(Component),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn bindKey(self: *Self, id: nux.ID, name: []const u8, key: nux.Input.Key) !void {
    const map = try self.components.get(id);
    const entry = try map.put(self, name);
    entry.mapping = .{ .key = key };
}
pub fn bindMouseButton(
    self: *Self,
    id: nux.ID,
    name: []const u8,
    button: nux.Input.MouseButton,
) !void {
    const map = try self.components.get(id);
    const entry = try map.put(self, name);
    entry.mapping = .{ .mouse_button = button };
}
pub fn bindGamepadButton(
    self: *Self,
    id: nux.ID,
    name: []const u8,
    button: nux.Input.GamepadButton,
) !void {
    const map = try self.components.get(id);
    const entry = try map.put(self, name);
    entry.mapping = .{ .gamepad_button = button };
}
pub fn bindGamepadAxis(
    self: *Self,
    id: nux.ID,
    name: []const u8,
    axis: nux.Input.GamepadAxis,
    sensivity: f32,
) !void {
    const map = try self.components.get(id);
    const entry = try map.put(self, name);
    entry.mapping = .{ .gamepad_axis = axis };
    entry.sensivity = sensivity;
}
pub fn bindMouseAxis(
    self: *Self,
    id: nux.ID,
    name: []const u8,
    axis: nux.Input.MouseAxis,
    sensivity: f32,
) !void {
    const map = try self.components.get(id);
    const entry = try map.put(self, name);
    entry.mapping = .{ .mouse_axis = axis };
    entry.sensivity = sensivity;
}
