const std = @import("std");
const nux = @import("../nux.zig");
const zgltf = @import("zgltf");

const Self = @This();
const Node = struct {
    span: ?nux.SpanAllocator.Span = null,
    sync: bool = true,
    vertices: std.ArrayList(f32) = .empty,
    layout: nux.Vertex.Layout = .make(.{}),
    primitive: nux.Vertex.Primitive = .triangles,

    fn initCapacity(allocator: std.mem.Allocator, capa: usize, primitive: nux.Vertex.Primitive, attributes: nux.Vertex.Attributes) !@This() {
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
pub fn loadGltfPrimitive(self: *Self, parent: nux.ID, gltf: *const zgltf.Gltf, primitive: *const zgltf.Gltf.Primitive) !nux.ID {
    // Create layout
    var attributes = nux.Vertex.Attributes{};
    var vertexCount: ?usize = null;
    for (primitive.attributes) |attribute| {
        switch (attribute) {
            .position => |idx| {
                vertexCount = gltf.data.accessors[idx].count;
                attributes.position = true;
            },
            .texcoord => attributes.texcoord = true,
            .normal => {},
            .color => attributes.color = true,
            else => {},
        }
    }
    if (vertexCount == null) {
        return error.VertexCountNotFound;
    }
    // Find primitive
    const vertex_primitive = switch (primitive.mode) {
        .triangles => nux.Vertex.Primitive.triangles,
        .lines => nux.Vertex.Primitive.lines,
        .points => nux.Vertex.Primitive.points,
        else => return error.UnsupportedPrimitive,
    };
    // Create mesh
    // var node = try Node.initCapacity(self.allocator, vertexCount.?, vertex_primitive, attributes);
    const value: u32 = 32;
    var node = try Node.initCapacity(self.allocator, vertexCount.?, vertex_primitive, @bitCast(value));
    // Resize mesh
    try node.vertices.resize(self.allocator, vertexCount.?);
    // Read values
    for (primitive.attributes) |attribute| {
        switch (attribute) {
            .position => |idx| {
                const accessor = gltf.data.accessors[idx];
                var it = accessor.iterator(f32, gltf, gltf.glb_binary.?);
                while (it.next()) |v| {
                    _ = v;
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
                const accessor = gltf.data.accessors[idx];
                var it = accessor.iterator(f32, gltf, gltf.glb_binary.?);
                var i: u32 = 0;
                while (it.next()) |n| : (i += 1) {
                    _ = n;
                    // vertices.items[initial_vertex + i].normal = .{ n[0], n[1], n[2] };
                }
            },
            else => {},
        }
    }
    return self.nodes.new(parent, node);
}
pub fn syncGPU(self: *Self) !void {
    for (self.nodes.data.items) |*mesh| {
        if (mesh.sync) {
            // Check gpu span allocation
            if (mesh.span == null or mesh.span.?.length < mesh.vertices.items.len) {
                mesh.span = self.graphics.vertex_span_allocator.alloc(mesh.vertices.items.len) orelse return error.OutOfVertices;
            }
            // Upload data
            // Reset sync flag
            mesh.sync = false;
        }
    }
}
