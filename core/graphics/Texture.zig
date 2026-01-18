const std = @import("std");
const nux = @import("../nux.zig");
const zigimg = @import("zigimg");

const Self = @This();

nodes: nux.NodePool(struct {
    data: ?[]u8 = null,
    size: nux.Vec2 = .zero(),
    pub fn init(_: *Self) !@This() {
        return .{};
    }
    pub fn deinit(self: *Self, texture: *@This()) void {
        if (texture.data) |data| {
            self.allocator.free(data);
        }
    }
}),
node: *nux.Node,
logger: *nux.Logger,
disk: *nux.Disk,
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn load(self: *Self, parent: nux.NodeID, path: []const u8) !nux.NodeID {
    const id = try self.nodes.new(parent);
    const texture = self.nodes.get(id) catch unreachable;

    const data = try self.disk.read(path, self.allocator);
    errdefer self.allocator.free(data);
    var image = try zigimg.Image.fromMemory(self.allocator, data);
    defer image.deinit(self.allocator);

    self.logger.info("{d}x{d}", .{ image.width, image.height });

    texture.data = data;
    return id;
}
