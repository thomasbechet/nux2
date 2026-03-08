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
const Component = struct {
    data: ?[]u8 = null,
    path: ?[]const u8 = null, // Nonnull if loaded from file
    sync: bool = false,
    info: nux.Platform.GPU.TextureInfo = .{},
    handle: ?nux.GPU.Texture = null,

    pub fn deinit(self: *Self, comp: *Component) void {
        if (comp.data) |data| {
            self.allocator.free(data);
        }
        if (comp.path) |path| {
            self.allocator.free(path);
        }
        if (comp.handle) |*handle| {
            handle.deinit();
        }
        comp.* = .{};
    }
    pub fn save(self: *Self, id: nux.ID, writer: *nux.Writer) !void {
        const node = try self.components.get(id);
        if (node.path != null) {
            try writer.write(node.path);
        } else if (node.data != null) {
            try writer.write(node.data);
        }
    }
    pub fn load(self: *Self, id: nux.ID, reader: *nux.Reader) !void {
        const node = try self.components.get(id);
        if (try reader.takeOptionalBytes()) |path| { // File source
            node.path = try self.allocator.dupe(u8, path);
            try self.addFromFile(id, path);
        } else if (try reader.takeOptionalBytes()) |data| { // Data source
            try self.addFromData(id, data);
        }
    }
    pub fn shortDescription(self: *Self, id: nux.ID, w: *std.Io.Writer) !void {
        const node = try self.components.get(id);
        try w.print("{d}x{d} ", .{ node.info.width, node.info.height });
        if (node.path) |path| {
            try w.print("{s}", .{path});
        }
    }
};

components: nux.Components(Component),
node: *nux.Node,
logger: *nux.Logger,
file: *nux.File,
graphics: *nux.Graphics,
gpu: *nux.GPU,
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn addFromGltfImage(self: *Self, id: nux.ID, image: *const zgltf.Gltf.Image) !void {
    if (image.data) |data| {
        try self.addFromData(id, data);
    }
}
pub fn addFromFile(self: *Self, id: nux.ID, path: []const u8) !void {
    const component = try self.components.addPtr(id);
    // Read file
    const data = try self.file.read(path, self.allocator);
    errdefer self.allocator.free(data);
    // Load image
    var image = try zigimg.Image.fromMemory(self.allocator, data);
    defer image.deinit(self.allocator);
    // Set as source
    component.data = data;
    component.path = try self.allocator.dupe(u8, path);
    component.sync = false;
}
pub fn addFromData(self: *Self, id: nux.ID, data: []const u8) !void {
    const component = try self.components.addPtr(id);
    // Load image
    var img = try zigimg.Image.fromMemory(self.allocator, data);
    defer img.deinit(self.allocator);
    try img.convert(self.allocator, .rgba32);
    // Deinit node
    component.data = try self.allocator.dupe(u8, img.rawBytes());
    component.info.width = @intCast(img.width);
    component.info.height = @intCast(img.height);
}
pub fn syncGPU(self: *Self) !void {
    var it = self.components.values();
    while (it.next()) |texture| {
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
    const node = try self.components.get(id);
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
