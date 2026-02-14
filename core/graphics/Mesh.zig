const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Node = struct {
    span: ?nux.SpanAllocator.Span = null,
    dirty: bool = true,
    vertices: std.ArrayList(f32) = .empty,
    layout: nux.Vertex.Layout = .make(.{}),
    primitive: nux.Vertex.Primitive = .triangles,
};

allocator: std.mem.Allocator,
nodes: nux.NodePool(Node),
graphics: *nux.Graphics,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn newCapacity(self: *Self, parent: nux.ID, capa: u32, primitive: nux.Vertex.Primitive, attributes: nux.Vertex.Attributes) !nux.ID {
    var node = Node{
        .primitive = primitive,
        .layout = .make(attributes),
    };
    try node.vertices.ensureTotalCapacity(self.allocator, node.layout.stride * capa);
    return try self.nodes.new(parent, node);
}
pub fn delete(self: *Self, id: nux.ID) !void {
    const node = try self.nodes.get(id);
    if (node.span) |span| {
        self.graphics.vertex_span_allocator.free(span);
    }
}
pub fn pushVertex(self: *Self, id: nux.ID) !void {

}
pub fn syncGPU(self: *Self) !void {
    for (self.nodes.data.items) |mesh| {
        if (mesh.dirty) {
            // Check gpu span allocation
            if (mesh.span == null or mesh.span.?.length < mesh.vertices.items.len) {
                mesh.span = try self.graphics.vertex_span_allocator.alloc(mesh.vertices.items.len);
            }
            // Upload data
            mesh.dirty = false;
        }
    }
}
