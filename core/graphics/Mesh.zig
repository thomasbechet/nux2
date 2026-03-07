const std = @import("std");
const nux = @import("../nux.zig");
const zgltf = @import("zgltf");

const Self = @This();

allocator: std.mem.Allocator,
components: nux.Components(struct {
    span: ?nux.SpanAllocator.Span = null,
    vertices: std.ArrayList(f32) = .empty,
    layout: nux.Vertex.Layout = .make(.{}),
    primitive: nux.Vertex.Primitive = .triangles,
    sync: bool = false,

    pub fn deinit(self: *Self, component: *@This()) void {
        component.vertices.deinit(self.allocator);
        if (component.span) |span| {
            try self.vertex_span_allocator.free(span);
        }
    }
    pub fn shortDescription(_: *Self, component: *const @This(), w: *std.Io.Writer) !void {
        try w.print("{d} vertices ", .{component.vertices.items.len});
        if (component.span) |span| {
            try w.print("[{d}-{d}]", .{ span.offset, span.offset + span.length });
        }
    }

    fn initCapacity(allocator: std.mem.Allocator, capa: usize, primitive: nux.Vertex.Primitive, attributes: nux.Vertex.Attributes) !@This() {
        var node = @This(){
            .primitive = primitive,
            .layout = .make(attributes),
        };
        try node.vertices.ensureTotalCapacity(allocator, node.layout.stride * capa);
        return node;
    }
}),
config: *nux.Config,
gpu: *nux.GPU,
vertex_buffer: nux.GPU.Buffer,
vertex_span_allocator: nux.SpanAllocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.vertex_span_allocator = try .init(
        self.allocator,
        try self.config.getInt(usize, "Graphics.defaultVertexBufferSize"),
        try self.config.getInt(usize, "Graphics.defaultVertexBufferSpanCapacity"),
    );
    self.vertex_buffer = try .init(self.gpu, .storage, self.vertex_span_allocator.size);
}
pub fn deinit(self: *Self) void {
    self.vertex_span_allocator.deinit();
    self.vertex_buffer.deinit();
}
pub fn newCapacity(self: *Self, parent: nux.ID, capa: u32, primitive: nux.Vertex.Primitive, attributes: nux.Vertex.Attributes) !nux.ID {
    return try self.components.new(parent, try .initCapacity(self.allocator, capa, primitive, attributes));
}
pub fn resize(self: *Self, id: nux.ID, size: u32) !void {
    const component = try self.components.get(id);
    const old_size = component.vertices.items.len;
    try component.vertices.resize(self.allocator, old_size * component.layout.stride);
    if (size > old_size) {
        @memset(component.vertices.items[old_size..], 0);
    }
    component.sync = false;
}
pub fn loadGltfPrimitive(self: *Self, id: nux.ID, gltf: *const zgltf.Gltf, primitive: *const zgltf.Gltf.Primitive) !void {
    const component = try self.components.get(id);
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
    try component.initCapacity(self.allocator, vertexCount.?, vertex_primitive, attributes);
    // Resize mesh
    try component.vertices.resize(self.allocator, vertexCount.? * component.layout.stride);
    // Read values
    for (primitive.attributes) |attribute| {
        switch (attribute) {
            .position => |idx| {
                if (component.layout.position) |position| {
                    const accessor = gltf.data.accessors[idx];
                    var it = accessor.iterator(f32, gltf, gltf.glb_binary.?);
                    var i: usize = 0;
                    while (it.next()) |v| : (i += 1) {
                        var buf = component.vertices.items[component.layout.stride * i + position ..];
                        buf[0] = v[0];
                        buf[1] = v[1];
                        buf[2] = v[2];
                    }
                }
            },
            .texcoord => |idx| {
                if (component.layout.texcoord) |texcoord| {
                    const accessor = gltf.data.accessors[idx];
                    var it = accessor.iterator(f32, gltf, gltf.glb_binary.?);
                    var i: u32 = 0;
                    while (it.next()) |v| : (i += 1) {
                        var buf = component.vertices.items[component.layout.stride * i + texcoord ..];
                        buf[0] = v[0];
                        buf[1] = v[1];
                    }
                }
            },
            .color => |idx| {
                if (component.layout.color) |color| {
                    const accessor = gltf.data.accessors[idx];
                    var it = accessor.iterator(f32, gltf, gltf.glb_binary.?);
                    var i: u32 = 0;
                    while (it.next()) |v| : (i += 1) {
                        var buf = component.vertices.items[component.layout.stride * i + color ..];
                        buf[0] = v[0];
                        buf[1] = v[1];
                        buf[2] = v[2];
                    }
                }
            },
            .normal => |idx| {
                if (component.layout.normal) |normal| {
                    const accessor = gltf.data.accessors[idx];
                    var it = accessor.iterator(f32, gltf, gltf.glb_binary.?);
                    var i: u32 = 0;
                    while (it.next()) |v| : (i += 1) {
                        var buf = component.vertices.items[component.layout.stride * i + normal ..];
                        buf[0] = v[0];
                        buf[1] = v[1];
                        buf[2] = v[2];
                    }
                }
            },
            else => {},
        }
    }
}
pub fn syncGPU(self: *Self) !void {
    for (self.components.data.items) |*mesh| {
        if (!mesh.sync) {
            // Check gpu span allocation
            if (mesh.span == null or mesh.span.?.length < mesh.vertices.items.len) {
                mesh.span = self.vertex_span_allocator.alloc(mesh.vertices.items.len) orelse return error.OutOfVertices;
            }
            // Upload data
            if (mesh.span) |span| {
                try self.vertex_buffer.update(
                    span.offset,
                    span.length,
                    mesh.vertices.items,
                );
            }
            // Reset sync flag
            mesh.sync = true;
        }
    }
}
