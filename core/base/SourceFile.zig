const std = @import("std");
const nux = @import("../nux.zig");

const Module = @This();
const Node = struct {
    path: ?[]const u8 = null,
    source: ?[]const u8 = null,

    pub fn init(_: *Module) !@This() {
        return .{};
    }
    pub fn deinit(self: *@This(), mod: *Module) void {
        if (self.path) |path| {
            mod.allocator.free(path);
        }
        if (self.source) |source| {
            mod.allocator.free(source);
        }
    }
};

allocator: std.mem.Allocator,
lua: *nux.Lua,
logger: *nux.Logger,
disk: *nux.Disk,
nodes: nux.NodePool(Node),

pub fn init(self: *Module, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn load(self: *Module, parent: nux.NodeID, path: []const u8) !nux.NodeID {
    const node = try self.nodes.new(parent);
    const source = try self.disk.readEntry(path, self.allocator);
    errdefer self.allocator.free(source);
    const path_copy = try self.allocator.dupe(u8, path);
    errdefer self.allocator.free(path_copy);
    node.data.* = .{
        .path = path_copy,
        .source = source,
    };
    return node.id;
}
pub fn getSource(self: *Module, id: nux.NodeID) ![]const u8 {
    return (try self.nodes.get(id)).source orelse unreachable;
}
