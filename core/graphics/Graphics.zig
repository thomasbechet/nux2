const std = @import("std");
const nux = @import("../nux.zig");
const Gltf = @import("zgltf").Gltf;

const Self = @This();

config: *nux.Config,
node: *nux.Node,
logger: *nux.Logger,
file: *nux.File,
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
    // Read buffer aligned
    const buffer: []align(std.mem.Alignment.@"4".toByteUnits()) u8 = @alignCast(try self.file.readAligned(path, self.allocator, std.mem.Alignment.@"4"));
    defer self.allocator.free(buffer);

    // Load gltf
    var gltf = Gltf.init(self.allocator);
    defer gltf.deinit();
    try gltf.parse(buffer);

    // Create assets nodes
    const meshes = try self.node.new(parent);
    try self.node.setName(meshes, "mesh");
    const textures = try self.node.new(parent);
    try self.node.setName(textures, "texture");

    // Create meshes
    for (gltf.data.meshes) |mesh| {
        for (mesh.primitives, 0..) |primitive, i| {
            // Create mesh
            const node = try self.mesh.loadGltfPrimitive(meshes, &gltf, &primitive);
            // Set name
            if (mesh.name) |name| {
                if (i == 0) {
                    try self.node.setName(node, name);
                } else {
                    try self.node.setNameFormat(node, "{s}_{d}", .{ name, i });
                }
            }
        }
    }

    // Create textures
    for (gltf.data.images) |image| {
        // Create texture
        const node = try self.texture.loadGltfImage(textures, &gltf, &image);
        if (image.name) |name| {
            try self.node.setName(node, name);
        }
    }

    // Create nodes
    for (gltf.data.scenes) |scene| {

        // Create root node
        const root = try self.node.new(parent);
        if (scene.name) |name| {
            try self.node.setName(root, name);
        }

        // Iterate nodes
        if (scene.nodes) |indices| {
            for (indices) |index| {
                const gltf_node = gltf.data.nodes[index];

                // const node: nux.ID = undefined;
                // if (gltf_node.parent) |gltf_parent| {
                //     node = try self.node.new(gltf_parent)
                // } else {}

                // Set name
                if (gltf_node.name) |name| {
                    self.logger.info("{s}", .{name});
                }
            }
        }
    }

    return .null;
}
