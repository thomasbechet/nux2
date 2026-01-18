const std = @import("std");
const nux = @import("../nux.zig");
const Input = nux.Input;

const Self = @This();

allocator: std.mem.Allocator,
logger: *nux.Logger,
nodes: nux.NodePool(struct {
    const Entry = struct {
        mapping: union(enum) {
            key: Input.Key,
        },
    };
    entries: std.StringHashMap(Entry),
    sensivity: f32,

    pub fn init(self: *Self) !@This() {
        return .{
            .entries = .init(self.allocator),
            .sensivity = 1,
        };
    }
    pub fn deinit(_: *Self, data: *@This()) void {
        data.entries.deinit();
    }
}),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn new(self: *Self, parent: nux.NodeID) !nux.NodeID {
    return (try self.nodes.new(parent)).id;
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
