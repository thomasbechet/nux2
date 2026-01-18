const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Type = enum {
    lua,
    wren,
};

allocator: std.mem.Allocator,
lua: *nux.Lua,
logger: *nux.Logger,
cart: *nux.Cart,
nodes: nux.NodePool(union(enum) {
    lua: struct {
        path: []const u8,
        source: []const u8,
    },
    none,

    pub fn init(_: *Self) !@This() {
        return .none;
    }
    pub fn deinit(self: *Self, script: *@This()) void {
        switch (script.*) {
            .lua => |*lua| {
                self.allocator.free(lua.path);
                self.allocator.free(lua.source);
            },
            .none => {},
        }
    }
}),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn load(self: *Self, parent: nux.NodeID, path: []const u8) !nux.NodeID {
    const id = try self.nodes.new(parent);
    const source = try self.cart.readAlloc(path, self.allocator);
    errdefer self.allocator.free(source);
    const script = self.nodes.get(id) catch unreachable;
    script.* = .{ .lua = .{
        .path = try self.allocator.dupe(u8, path),
        .source = source,
    } };
    return id;
}
