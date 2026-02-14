const std = @import("std");
const nux = @import("../nux.zig");
const gltf = @import("zgltf");

const Self = @This();
const Node = struct {
    span: ?nux.SpanAllocator.Span = null,
    sync: bool = true,
    vertices: std.ArrayList(f32) = .empty,
    layout: nux.Vertex.Layout = .make(.{}),
    primitive: nux.Vertex.Primitive = .triangles,

    fn initCapacity(allocator: std.mem.Allocator, capa: u32, primitive: nux.Vertex.Primitive, attributes: nux.Vertex.Attributes) !@This() {
        var node = Node{
            .primitive = primitive,
            .layout = .make(attributes),
        };
        try node.vertices.ensureTotalCapacity(allocator, node.layout.stride * capa);
        return node;
    }
};

allocator: std.mem.Allocator,
nodes: nux.NodePool(Node),
graphics: *nux.Graphics,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn newCapacity(self: *Self, parent: nux.ID, capa: u32, primitive: nux.Vertex.Primitive, attributes: nux.Vertex.Attributes) !nux.ID {
    return try self.nodes.new(parent, try .initCapacity(self.allocator, capa, primitive, attributes));
}
pub fn delete(self: *Self, id: nux.ID) !void {
    const node = try self.nodes.get(id);
    if (node.span) |span| {
        self.graphics.vertex_span_allocator.free(span);
    }
}
pub fn resize(self: *Self, id: nux.ID, size: u32) !void {
    const node = try self.nodes.get(id);
    const old_size = node.vertices.items.len;
    try node.vertices.resize(self.allocator, old_size * node.layout.stride);
    if (size > old_size) {
        @memset(node.vertices.items[old_size..], 0);
    }
}
pub fn loadGltfPrimitive(self: *Self, data: *const gltf.Gltf.Data, primitive: *const gltf.Gltf.Primitive) !nux.ID {
    // Create layout
    const attributes = nux.Vertex.Attributes{};
    var vertexCount: ?usize = null;
    for (primitive.attributes) |attribute| {
        switch (attribute) {
            .position => |idx| {
                const accessor = data.accessors.items[idx];
attributes.position = true;
            },
            .texcoord => attributes.texcoord = true,
            .normal => {},
            .color => attributes.color = true,
            else => {},
        }
    }
    const layout = nux.Vertex.Layout.make(attributes);
    // Create mesh
    const node = try Node.newCapacity(self.allocator, , primitive, attributes);
    for (primitive.attributes) |attribute| {
        switch (attribute) {
            .position => |idx| {
                const accessor = gltf.data.accessors.items[idx];
                var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                while (it.next()) |v| {
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
pub fn syncGPU(self: *Self) !void {
    for (self.nodes.data.items) |mesh| {
        if (mesh.sync) {
            // Check gpu span allocation
            if (mesh.span == null or mesh.span.?.length < mesh.vertices.items.len) {
                mesh.span = try self.graphics.vertex_span_allocator.alloc(mesh.vertices.items.len);
            }
            // Upload data
            // Reset sync flag
            mesh.sync = false;
        }
    }
}
