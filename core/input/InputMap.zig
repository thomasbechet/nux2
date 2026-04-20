const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Component = struct {
    const Entry = struct {
        mapping: union(enum) {
            key: nux.Input.Key,
        },
    };
    entries: std.StringHashMap(Entry),
    sensivity: f32,

    pub fn init(mod: *Self) !Component {
        return .{
            .entries = .init(mod.allocator),
            .sensivity = 1,
        };
    }
    pub fn deinit(self: *Component, _: *Self) void {
        self.entries.deinit();
    }
};

allocator: std.mem.Allocator,
components: nux.Components(Component),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn bindKey(self: *Self, id: nux.ID, name: []const u8, key: nux.Input.Key) !void {
    // const map = try self.objects.get(id);
    // const entry = try map.entries.getOrPut(name);
    // entry.value_ptr.mapping.key = key;
    _ = self;
    _ = id;
    _ = name;
    _ = key;
}
