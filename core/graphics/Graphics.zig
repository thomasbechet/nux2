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
pub fn loadGltf(self: *Self, path: []const u8) !nux.ID {
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
            // const node = self.mesh.
            // Read data
            for (primitive.attributes) |attribute| {
                switch (attribute) {
                    .position => |idx| {
                        const accessor = gltf.data.accessors.items[idx];
                        var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                        while (it.next()) |v| {
                            self.mesh.setPosition(
                                id,
                            );
                            // try vertices.append(.{
                            //     .pos = .{ v[0], v[1], v[2] },
                            //     .normal = .{ 1, 0, 0 },
                            //     .color = .{ 1, 1, 1, 1 },
                            //     .uv_x = 0,
                            //     .uv_y = 0,
                            // });
                        }
                    },
                    .texcoord => |idx| {
                        const accessor = gltf.data.accessors.items[idx];
                        var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                        var i: u32 = 0;
                        while (it.next()) |n| : (i += 1) {
                            // vertices.items[initial_vertex + i].normal = .{ n[0], n[1], n[2] };
                        }
                    },
                    else => {},
                }
            }
        }
    }

    // Create textures
    for (gltf.data.images) |image| {}

    // Create nodes

    return .null;
}
