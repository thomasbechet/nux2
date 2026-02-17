const std = @import("std");
const nux = @import("../nux.zig");
const zigimg = @import("zigimg");
const zgltf = @import("zgltf");

const Self = @This();
const Node = struct {
    data: ?[]u8 = null,
    size: nux.Vec2 = .zero(),
    path: ?[]const u8 = null,
};

nodes: nux.NodePool(Node),
node: *nux.Node,
logger: *nux.Logger,
file: *nux.File,
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
fn deinitNode(self: *Self, node: *Node) !void {
    if (node.data) |data| {
        self.allocator.free(data);
    }
    if (node.path) |path| {
        self.allocator.free(path);
    }
}
pub fn delete(self: *Self, id: nux.ID) !void {
    const node = try self.nodes.get(id);
    try self.deinitNode(node);
}
pub fn save(self: *Self, id: nux.ID, writer: *nux.Writer) !void {
    const node = try self.nodes.get(id);
    try writer.write(node.*);
}
pub fn load(self: *Self, id: nux.ID, reader: *nux.Reader) !void {
    const node = try self.nodes.get(id);
    if (try reader.takeOptionalBytes()) |path| {
        node.path = try self.allocator.dupe(u8, path);
        try self.loadFromPath(id, path);
    }
}
pub fn loadGltfImage(self: *Self, parent: nux.ID, gltf: *const zgltf.Gltf, image: *const zgltf.Gltf.Image) !nux.ID {
    _ = gltf;
    if (image.data) |data| {
        var img = try zigimg.Image.fromMemory(self.allocator, data);
        defer img.deinit(self.allocator);
    }
    return try self.nodes.new(parent, .{});
}
pub fn newFromPath(self: *Self, parent: nux.ID, path: []const u8) !nux.ID {
    const id = try self.nodes.new(parent, .{});
    try self.loadFromPath(id, path);
    return id;
}
pub fn loadFromPath(self: *Self, id: nux.ID, path: []const u8) !void {
    const node = try self.nodes.get(id);
    const data = try self.file.read(path, self.allocator);
    errdefer self.allocator.free(data);
    var image = try zigimg.Image.fromMemory(self.allocator, data);
    defer image.deinit(self.allocator);
    try self.deinitNode(node); // Free previous memory
    node.data = data;
    node.path = try self.allocator.dupe(u8, path);
}
