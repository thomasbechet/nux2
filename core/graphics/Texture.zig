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
    handle: ?nux.GPU.Texture = null,

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

    fn initTransparent(mod: *Self, width: u32, height: u32) !Texture {
        const texture = Texture{
            .data = try mod.allocator.alloc(u8, width * height * 4),
            .info = .{
                .width = width,
                .height = height,
            },
        };
        @memset(texture.data.?, 0);
        return texture;
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
    pub fn syncGPU(self: *Texture, gpu: *nux.GPU) !void {
        if (!self.sync) {
            // Check renderer allocation
            if (self.handle == null) {
                self.handle = try .init(gpu, self.info);
            }
            // Upload data
            if (self.data != null) {
                try self.handle.?.update(
                    0,
                    0,
                    self.info.width,
                    self.info.height,
                    self.data.?,
                );
            }
            // Reset sync flag
            self.sync = true;
        }
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
pub fn addTransparent(self: *Self, id: nux.ID, width: u32, height: u32) !void {
    try self.components.addWith(id, try .initTransparent(self, width, height));
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
        try texture.syncGPU(self.gpu);
    }
}
pub fn blit(self: *Self, id: nux.ID, pos: nux.Vec2i) !void {
    const node = try self.components.get(id);

    var cb = nux.Graphics.CommandBuffer.init(self.allocator);
    defer cb.deinit();
    try cb.blit(.{
        .source = id,
        .pos = pos,
        .box = .init(0, 0, node.info.width, node.info.height),
        .scale = 2,
    });
    try cb.rectangle(.{
        .box = .init(10, 10, 100, 100),
    });
    try cb.rectangle(.{
        .box = .init(110, 110, 100, 100),
    });
    try cb.text(.{
        .position = .init(200, 200),
        .text = "Coucou Juliaaaaaa !",
        .scale = 4,
    });
    try self.gpu.render(&cb);
}
