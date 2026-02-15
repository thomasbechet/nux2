const std = @import("std");
const nux = @import("../nux.zig");
const Gltf = @import("zgltf").Gltf;

const Self = @This();

config: *nux.Config,
node: *nux.Node,
logger: *nux.Logger,
allocator: std.mem.Allocator,
mesh: *nux.Mesh,
texture: *nux.Texture,
material: *nux.Material,
staticmesh: *nux.StaticMesh,
vertex_span_allocator: nux.SpanAllocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.vertex_span_allocator = try .init(self.allocator, self.config.sections.graphics.defaultVertexBufferSize, self.config.sections.graphics.defaultVertexBufferSpanCapacity);
}
pub fn deinit(self: *Self) void {
    self.vertex_span_allocator.deinit();
}
pub fn loadGltf(self: *Self, parent: nux.ID, path: []const u8) !nux.ID {
    const buffer = try std.fs.cwd().readFileAllocOptions(self.allocator, path, 2_000_000, null, std.mem.Alignment.@"4", null);
    defer self.allocator.free(buffer);

    // Load gltf
    var gltf = Gltf.init(self.allocator);
    defer gltf.deinit();
    try gltf.parse(buffer);

    // Create meshes
    for (gltf.data.meshes) |mesh| {
        for (mesh.primitives) |primitive| {
            // Create mesh
            const node = try self.mesh.loadGltfPrimitive(parent, &gltf, &primitive);
            _ = node;
        }
    }

    // Create textures
    for (gltf.data.images) |image| {
        _ = image;
    }

    // Create nodes

    return .null;
}
