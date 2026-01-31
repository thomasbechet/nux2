const std = @import("std");
const nux = @import("../nux.zig");
const Input = nux.Input;

const Module = @This();
const Node = struct {
    const Entry = struct {
        mapping: union(enum) {
            key: Input.Key,
        },
    };
    entries: std.StringHashMap(Entry),
    sensivity: f32,

    pub fn init(self: *Module) !@This() {
        return .{
            .entries = .init(self.allocator),
            .sensivity = 1,
        };
    }
    pub fn deinit(self: *@This(), _: *Module) void {
        self.entries.deinit();
    }
};

allocator: std.mem.Allocator,
logger: *nux.Logger,
nodes: nux.NodePool(Node),

pub fn init(self: *Module, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn new(self: *Module, parent: nux.NodeID) !nux.NodeID {
    return (try self.nodes.new(parent)).id;
}
pub fn bindKey(self: *Module, id: nux.NodeID, name: []const u8, key: Input.Key) !void {
    // const map = try self.objects.get(id);
    // const entry = try map.entries.getOrPut(name);
    // entry.value_ptr.mapping.key = key;
    _ = self;
    _ = id;
    _ = name;
    _ = key;
}
