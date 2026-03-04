const std = @import("std");
const nux = @import("../nux.zig");
const zigimg = @import("zigimg");
const zgltf = @import("zgltf");

pub const Filtering = enum(u32) {
    nearest = 0,
    linear = 1,
};

pub const Type = enum(u32) {
    image_rgba = 0,
    image_indexed = 1,
    render_target = 2,
};

const Self = @This();
const Node = struct {
    data: ?[]u8 = null,
    path: ?[]const u8 = null, // Nonnull if loaded from file
    sync: bool = false,
    info: nux.GPU.TextureInfo = .{},
    handle: ?nux.GPU.Texture = null,
};

nodes: nux.NodePool(Node),
node: *nux.Node,
logger: *nux.Logger,
file: *nux.File,
graphics: *nux.Graphics,
gpu: *nux.GPU,
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
    if (node.handle) |*handle| {
        handle.deinit();
    }
    node.* = .{};
}
pub fn delete(self: *Self, id: nux.ID) !void {
    const node = try self.nodes.get(id);
    try self.deinitNode(node);
}
pub fn save(self: *Self, id: nux.ID, writer: *nux.Writer) !void {
    const node = try self.nodes.get(id);
    if (node.path != null) {
        try writer.write(node.path);
    } else if (node.data != null) {
        try writer.write(node.data);
    }
}
pub fn load(self: *Self, id: nux.ID, reader: *nux.Reader) !void {
    const node = try self.nodes.get(id);
    if (try reader.takeOptionalBytes()) |path| { // File source
        node.path = try self.allocator.dupe(u8, path);
        try self.loadFromPath(id, path);
    } else if (try reader.takeOptionalBytes()) |data| { // Data source
        try self.loadFromData(id, data);
    }
}
pub fn shortDescription(self: *Self, id: nux.ID, w: *std.Io.Writer) !void {
    const node = try self.nodes.get(id);
    try w.print("{d}x{d} ", .{ node.info.width, node.info.height });
    if (node.path) |path| {
        try w.print("{s}", .{path});
    }
}
pub fn loadGltfImage(self: *Self, parent: nux.ID, image: *const zgltf.Gltf.Image) !nux.ID {
    const id = try self.nodes.new(parent, .{});
    if (image.data) |data| {
        try self.loadFromData(id, data);
    }
    return id;
}
pub fn newFromPath(self: *Self, parent: nux.ID, path: []const u8) !nux.ID {
    const id = try self.nodes.new(parent, .{});
    try self.loadFromPath(id, path);
    return id;
}
pub fn loadFromPath(self: *Self, id: nux.ID, path: []const u8) !void {
    const node = try self.nodes.get(id);
    // Read file
    const data = try self.file.read(path, self.allocator);
    errdefer self.allocator.free(data);
    // Load image
    var image = try zigimg.Image.fromMemory(self.allocator, data);
    defer image.deinit(self.allocator);
    // Deinit node
    try self.deinitNode(node);
    // Set as source
    node.data = data;
    node.path = try self.allocator.dupe(u8, path);
    node.sync = false;
}
pub fn loadFromData(self: *Self, id: nux.ID, data: []const u8) !void {
    const node = try self.nodes.get(id);
    // Load image
    var img = try zigimg.Image.fromMemory(self.allocator, data);
    defer img.deinit(self.allocator);
    try img.convert(self.allocator, .rgba32);
    // Deinit node
    try self.deinitNode(node);
    node.data = try self.allocator.dupe(u8, img.rawBytes());
    node.info.width = @intCast(img.width);
    node.info.height = @intCast(img.height);
    node.sync = false;
}
pub fn syncGPU(self: *Self) !void {
    for (self.nodes.data.items) |*texture| {
        if (!texture.sync) {
            // Check gpu allocation
            if (texture.handle == null) {
                texture.handle = try .init(self.gpu, texture.info);
            }
            // Upload data
            if (texture.data != null) {
                try texture.handle.?.update(0, 0, texture.info.width, texture.info.height, texture.data.?);
            }
            // Reset sync flag
            texture.sync = true;
        }
    }
}
pub fn blit(self: *Self, id: nux.ID, pos: nux.Vec2) !void {
    const node = try self.nodes.get(id);
    var encoder = nux.GPU.Encoder.init(self.gpu);
    defer encoder.deinit();
    try encoder.bindFramebuffer(null);
    try encoder.viewport(@intFromFloat(pos.data[0]), @intFromFloat(pos.data[1]), node.info.width, node.info.height);
    try encoder.bindPipeline(&self.graphics.pipelines.blit);
    if (node.handle == null) {
        node.handle = try .init(self.gpu, node.info);
    }
    try encoder.bindTexture(.texture, &node.handle.?);
    try encoder.pushU32(.texture_width, node.info.width);
    try encoder.pushU32(.texture_height, node.info.height);
    try encoder.drawFullQuad();
    try encoder.submit();
}
