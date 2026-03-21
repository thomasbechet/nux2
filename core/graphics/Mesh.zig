const std = @import("std");
const nux = @import("../nux.zig");
const zgltf = @import("zgltf");

const Self = @This();

const Mesh = struct {
    span: ?nux.SpanAllocator.Span = null,
    vertices: std.ArrayList(f32) = .empty,
    layout: nux.Vertex.Layout = .make(.{}),
    primitive: nux.Vertex.Primitive = .triangles,
    sync: bool = false,

    pub fn deinit(self: *Mesh, mod: *Self) void {
        self.vertices.deinit(mod.allocator);
        if (self.span) |span| {
            mod.gpu.vertex_span_allocator.free(span) catch {};
        }
    }
    pub fn description(self: *const @This(), _: *Self, w: *std.Io.Writer) !void {
        try w.print("{d} vertices ", .{self.vertices.items.len});
        if (self.span) |span| {
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

    pub fn syncGPU(self: *Mesh, gpu: *nux.GPU) !void {
        if (!self.sync) {
            // Check renderer span allocation
            if (self.span == null or self.span.?.length < self.vertices.items.len) {
                self.span = gpu.vertex_span_allocator.alloc(self.vertices.items.len * @sizeOf(f32)) orelse return error.OutOfVertices;
            }
            // Upload data
            if (self.span) |span| {
                try gpu.buffers.vertices.update(
                    span.offset * @sizeOf(f32),
                    span.length * @sizeOf(f32),
                    @ptrCast(&self.vertices.items),
                );
            }
            // Reset sync flag
            self.sync = true;
        }
    }
};

allocator: std.mem.Allocator,
components: nux.Components(Mesh),
config: *nux.Config,
gpu: *nux.GPU,

pub fn resize(self: *Self, id: nux.ID, size: u32) !void {
    const component = try self.components.get(id);
    const old_size = component.vertices.items.len;
    try component.vertices.resize(self.allocator, old_size * component.layout.stride);
    if (size > old_size) {
        @memset(component.vertices.items[old_size..], 0);
    }
    component.sync = false;
}
pub fn addFromGltfPrimitive(self: *Self, id: nux.ID, gltf: *const zgltf.Gltf, primitive: *const zgltf.Gltf.Primitive) !void {
    const component = try self.components.addPtr(id);

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
    component.primitive = switch (primitive.mode) {
        .triangles => nux.Vertex.Primitive.triangles,
        .lines => nux.Vertex.Primitive.lines,
        .points => nux.Vertex.Primitive.points,
        else => return error.UnsupportedPrimitive,
    };

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
    var it = self.components.values();
    while (it.next()) |mesh| {
        try mesh.syncGPU(self.gpu);
    }
}
