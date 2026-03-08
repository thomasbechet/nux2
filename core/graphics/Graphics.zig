const std = @import("std");
const nux = @import("../nux.zig");
const Gltf = @import("zgltf").Gltf;

const Self = @This();
const GPU = nux.GPU;

const GltfContext = struct {
    gltf: *const Gltf,
    meshes: nux.ID,
    textures: nux.ID,
};

config: *nux.Config,
node: *nux.Node,
gpu: *nux.GPU,
transform: *nux.Transform,
logger: *nux.Logger,
file: *nux.File,
mesh: *nux.Mesh,
texture: *nux.Texture,
material: *nux.Material,
staticmesh: *nux.StaticMesh,

allocator: std.mem.Allocator,
pipelines: struct {
    uber_opaque: GPU.Pipeline,
    uber_line: GPU.Pipeline,
    canvas: GPU.Pipeline,
    blit: GPU.Pipeline,
},

fn createNode(self: *Self, parent: nux.ID, ctx: *const GltfContext, index: usize) !nux.ID {
    // Get root node
    const gltf_node = ctx.gltf.data.nodes[index];

    // Create root node
    const node = try self.node.create(parent);
    if (gltf_node.name) |name| {
        try self.node.setName(node, name);
    }

    // Set transform
    if (gltf_node.matrix) |matrix| {
        _ = matrix;
    } else {
        try self.transform.components.add(node);
        try self.transform.setPosition(node, .init(gltf_node.translation));
        const rot = gltf_node.rotation;
        try self.transform.setRotation(node, .init(rot[0], rot[1], rot[2], rot[3]));
        try self.transform.setScale(node, .init(gltf_node.scale));
    }
    try self.transform.setParent(node, parent);

    // Mesh
    if (gltf_node.mesh) |idx| {
        try self.staticmesh.components.add(node);
        const mesh = &ctx.gltf.data.meshes[idx];
        if (mesh.name) |name| {
            try self.staticmesh.setMesh(node, try self.node.findChild(ctx.meshes, name));
        }
    }

    // Camera
    if (gltf_node.camera) |idx| {
        _ = idx;
    }

    // Light
    if (gltf_node.light) |idx| {
        _ = idx;
    }

    // Create children
    for (gltf_node.children) |child| {
        _ = try self.createNode(node, ctx, child);
    }

    return node;
}

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;

    // Create pipelines
    self.pipelines.uber_opaque = try .init(self.gpu, .{
        .type = .uber,
        .primitive = .triangles,
        .blend = false,
        .depth_test = true,
    });
    errdefer self.pipelines.uber_opaque.deinit();
    self.pipelines.uber_line = try .init(self.gpu, .{
        .type = .uber,
        .primitive = .lines,
        .blend = false,
        .depth_test = true,
    });
    errdefer self.pipelines.uber_line.deinit();
    self.pipelines.canvas = try .init(self.gpu, .{
        .type = .canvas,
        .primitive = .triangles,
        .blend = true,
        .depth_test = false,
    });
    errdefer self.pipelines.canvas.deinit();
    self.pipelines.blit = try .init(self.gpu, .{
        .type = .blit,
        .primitive = .triangles,
        .blend = true,
        .depth_test = false,
    });
    errdefer self.pipelines.blit.deinit();
}
pub fn deinit(self: *Self) void {
    self.pipelines.uber_opaque.deinit();
    self.pipelines.uber_line.deinit();
    self.pipelines.canvas.deinit();
    self.pipelines.blit.deinit();
}
pub fn onPostUpdate(self: *Self) !void {
    try self.mesh.syncGPU();
    try self.texture.syncGPU();
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
    const meshes = try self.node.create(parent);
    try self.node.setName(meshes, "Meshes");
    const textures = try self.node.create(parent);
    try self.node.setName(textures, "Textures");

    // Create meshes
    for (gltf.data.meshes) |mesh| {
        for (mesh.primitives, 0..) |primitive, i| {

            // Create mesh
            const node = try self.node.create(meshes);
            try self.mesh.addFromGltfPrimitive(node, &gltf, &primitive);

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
        const node = try self.node.create(textures);
        try self.texture.addFromGltfImage(node, &image);
        if (image.name) |name| {
            try self.node.setName(node, name);
        }
    }

    // Create context
    const ctx = GltfContext{
        .gltf = &gltf,
        .textures = textures,
        .meshes = meshes,
    };

    // Create nodes
    for (gltf.data.scenes) |scene| {

        // Create scene node
        const scene_node = try self.node.create(parent);
        try self.transform.components.add(scene_node);

        // Set name
        if (scene.name) |name| {
            try self.node.setName(scene_node, name);
        }

        // Create root nodes
        if (scene.nodes) |root_indices| {
            for (root_indices) |root_index| {
                _ = try self.createNode(scene_node, &ctx, root_index);
            }
        }
    }

    return .null;
}
