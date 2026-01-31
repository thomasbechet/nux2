const std = @import("std");
const nux = @import("../nux.zig");

const Module = @This();
const Node = union(enum) {
    lua: struct {
        path: []const u8,
        source: []const u8,
    },
    none,

    pub fn init(_: *Module) !@This() {
        return .none;
    }
    pub fn deinit(self: *@This(), mod: *Module) void {
        switch (self.*) {
            .lua => |*lua| {
                mod.allocator.free(lua.path);
                mod.allocator.free(lua.source);
            },
            .none => {},
        }
    }
};

const Type = enum {
    lua,
    wren,
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
    try self.lua.doString(source, path);
    const path_copy = try self.allocator.dupe(u8, path);
    errdefer self.allocator.free(path_copy);
    node.data.* = .{ .lua = .{
        .path = path_copy,
        .source = source,
    } };
    return node.id;
}
