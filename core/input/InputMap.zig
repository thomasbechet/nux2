const std = @import("std");
const nux = @import("../nux.zig");
const Input = nux.Input;

const Self = @This();
const Component = struct {
    const Entry = struct {
        mapping: union(enum) {
            key: Input.Key,
        },
    };
    entries: std.StringHashMap(Entry),
    sensivity: f32,

    pub fn init(self: *Self) !Component {
        return .{
            .entries = .init(self.allocator),
            .sensivity = 1,
        };
    }
    pub fn deinit(_: *Self, component: *Component) void {
        component.entries.deinit();
    }
};

allocator: std.mem.Allocator,
logger: *nux.Logger,
components: nux.Components(Component),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn bindKey(self: *Self, id: nux.ID, name: []const u8, key: Input.Key) !void {
    // const map = try self.objects.get(id);
    // const entry = try map.entries.getOrPut(name);
    // entry.value_ptr.mapping.key = key;
    _ = self;
    _ = id;
    _ = name;
    _ = key;
}
