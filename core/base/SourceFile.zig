const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Node = struct {
    path: ?[]const u8 = null,
    source: ?[]const u8 = null,
};

allocator: std.mem.Allocator,
lua: *nux.Lua,
logger: *nux.Logger,
file: *nux.File,
nodes: nux.NodePool(Node),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn delete(self: *Self, id: nux.ID) !void {
    const data = try self.nodes.get(id);
    if (data.path) |path| {
        self.allocator.free(path);
    }
    if (data.source) |source| {
        self.allocator.free(source);
    }
}
pub fn newFromPath(self: *Self, parent: nux.ID, path: []const u8) !nux.ID {
    const source = try self.file.read(path, self.allocator);
    errdefer self.allocator.free(source);
    const path_copy = try self.allocator.dupe(u8, path);
    errdefer self.allocator.free(path_copy);
    return try self.nodes.new(parent, .{ .path = path_copy, .source = source });
}
pub fn getSource(self: *Self, id: nux.ID) ![]const u8 {
    return (try self.nodes.get(id)).source orelse unreachable;
}
