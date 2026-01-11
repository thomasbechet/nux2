const std = @import("std");
const nux = @import("../nux.zig");
const Input = nux.Input;

const Self = @This();

allocator: std.mem.Allocator,
nodes: nux.NodePool(struct {
    const Entry = struct {
        mapping: union(enum) {
            key: Input.Key,
        },
    };
    entries: std.StringHashMap(Entry),
    sensivity: f32,
}),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn new(self: *Self, parent: nux.NodeID) !nux.NodeID {
    return try self.nodes.add(parent, .{
        .entries = .init(self.allocator),
        .sensivity = 1,
    });
}
pub fn delete(self: *Self, id: nux.NodeID) !void {
    const map = try self.nodes.get(id);
    map.entries.deinit();
    std.log.info("called", .{});
}
pub fn bindKey(self: *Self, id: nux.NodeID, name: []const u8, key: Input.Key) !void {
    // const map = try self.objects.get(id);
    // const entry = try map.entries.getOrPut(name);
    // entry.value_ptr.mapping.key = key;
    _ = self;
    _ = id;
    _ = name;
    _ = key;
}
