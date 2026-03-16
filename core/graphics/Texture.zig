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
const Texture = struct {
    data: ?[]u8 = null,
    path: ?[]const u8 = null, // Nonnull if loaded from file
    sync: bool = false,
    info: nux.Platform.GPU.TextureInfo = .{},
    handle: ?nux.Renderer.Texture = null,

    const Serialized = struct {
        path: ?[]const u8 = null,
        raw: ?struct {
            data: []u8,
            width: u32,
            height: u32,
        } = null,
    };

    pub fn deinit(self: *Texture, mod: *Self) void {
        if (self.data) |data| {
            mod.allocator.free(data);
        }
        if (self.path) |path| {
            mod.allocator.free(path);
        }
        if (self.handle) |*handle| {
            handle.deinit();
        }
        self.* = .{};
    }
    pub fn load(mod: *Self, reader: *nux.Reader) !Texture {
        const serialized = try reader.read(Serialized);
        if (serialized.path) |path| {
            return try .initFromFile(mod, path);
        } else if (serialized.raw) |raw| {
            return try .initFromRawPixels(mod, raw.width, raw.height, raw.data);
        }
        return .{};
    }
    pub fn save(self: *Texture, _: *Self, writer: *nux.Writer) !void {
        if (self.path) |path| {
            try writer.write(Serialized{
                .path = path,
            });
        } else if (self.data) |data| {
            try writer.write(Serialized{
                .raw = .{
                    .data = data,
                    .width = self.info.width,
                    .height = self.info.height,
                },
            });
        }
    }
    pub fn description(self: *Texture, _: *Self, w: *std.Io.Writer) !void {
        try w.print("{d}x{d} ", .{ self.info.width, self.info.height });
        if (self.path) |path| {
            try w.print("{s}", .{path});
        }
    }

    fn initFromFile(mod: *Self, path: []const u8) !Texture {
        // Read file
        const data = try mod.file.read(path, mod.allocator);
        errdefer mod.allocator.free(data);
        // Load image
        var image = try zigimg.Image.fromMemory(mod.allocator, data);
        defer image.deinit(mod.allocator);
        // Set as source
        return .{
            .data = data,
            .path = try mod.allocator.dupe(u8, path),
        };
    }
    fn initFromData(mod: *Self, data: []const u8) !Texture {
        // Load image
        var img = try zigimg.Image.fromMemory(mod.allocator, data);
        defer img.deinit(mod.allocator);
        try img.convert(mod.allocator, .rgba32);
        // Init node
        return try .initFromRawPixels(mod, @intCast(img.width), @intCast(img.height), img.rawBytes());
    }
    fn initFromRawPixels(mod: *Self, width: u32, height: u32, data: []const u8) !Texture {
        return .{
            .data = try mod.allocator.dupe(u8, data),
            .info = .{
                .width = width,
                .height = height,
            },
        };
    }
};

components: nux.Components(Texture),
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
    try self.components.addWith(id, try .initFromFile(self, path));
}
pub fn addFromData(self: *Self, id: nux.ID, data: []const u8) !void {
    try self.components.addWith(id, try .initFromData(self, data));
}
pub fn syncGPU(self: *Self) !void {
    var it = self.components.values();
    while (it.next()) |texture| {
        if (!texture.sync) {
            // Check renderer allocation
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
    var encoder = nux.Renderer.Encoder.init(self.gpu);
    defer encoder.deinit();
    try encoder.bindFramebuffer(null);
    try encoder.viewport(
        @intFromFloat(pos.data[0]),
        @intFromFloat(pos.data[1]),
        node.info.width,
        node.info.height,
    );
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
