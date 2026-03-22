const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const GPU = nux.Platform.GPU;

pub const Framebuffer = struct {
    handle: GPU.Handle,
    gpu: *Self,
};

pub const Pipeline = struct {
    handle: GPU.Handle,
    gpu: *Self,

    pub fn init(renderer: *Self, info: GPU.PipelineInfo) !Pipeline {
        return .{
            .handle = try renderer.gpu.vtable.create_pipeline(renderer.gpu.ptr, info),
            .gpu = renderer,
        };
    }
    pub fn deinit(self: *Pipeline) void {
        self.gpu.gpu.vtable.delete_pipeline(self.gpu.gpu.ptr, self.handle);
    }
};

pub const Texture = struct {
    handle: GPU.Handle,
    gpu: *Self,

    pub fn init(renderer: *Self, info: GPU.TextureInfo) !Texture {
        return .{
            .handle = try renderer.gpu.vtable.create_texture(renderer.gpu.ptr, info),
            .gpu = renderer,
        };
    }
    pub fn deinit(self: *Texture) void {
        self.gpu.gpu.vtable.delete_texture(self.gpu.gpu.ptr, self.handle);
    }
    pub fn update(self: *Texture, x: u32, y: u32, w: u32, h: u32, data: []const u8) !void {
        try self.gpu.gpu.vtable.update_texture(
            self.gpu.gpu.ptr,
            self.handle,
            x,
            y,
            w,
            h,
            data,
        );
    }
};

pub const Buffer = struct {
    handle: GPU.Handle,
    gpu: *Self,

    pub fn init(renderer: *Self, typ: GPU.BufferType, size: u64) !Buffer {
        return .{
            .gpu = renderer,
            .handle = try renderer.gpu.vtable.create_buffer(renderer.gpu.ptr, typ, size),
        };
    }
    pub fn deinit(self: *Buffer) void {
        self.gpu.gpu.vtable.delete_buffer(self.gpu.gpu.ptr, self.handle);
    }
    pub fn update(self: *Buffer, offset: u64, size: u64, data: []const u8) !void {
        try self.gpu.gpu.vtable.update_buffer(
            self.gpu.gpu.ptr,
            self.handle,
            offset,
            size,
            data,
        );
    }
};

const Encoder = struct {
    gpu: *Self,
    allocator: std.mem.Allocator,
    commands: std.ArrayList(GPU.Command),

    fn init(gpu: *Self) Encoder {
        return .{
            .gpu = gpu,
            .allocator = gpu.allocator,
            .commands = .empty,
        };
    }
    fn deinit(self: *Encoder) void {
        self.commands.deinit(self.gpu.allocator);
    }
    fn submit(self: *Encoder) !void {
        try self.gpu.gpu.vtable.submit_commands(self.gpu.gpu.ptr, self.commands.items);
        self.commands.clearRetainingCapacity();
    }

    fn bindFramebuffer(self: *Encoder, framebuffer: ?*const Framebuffer) !void {
        var handle: ?GPU.Handle = null;
        if (framebuffer) |fb| {
            handle = fb.handle;
        }
        try self.commands.append(self.allocator, .{
            .bind_framebuffer = .{ .framebuffer = handle },
        });
    }
    fn bindPipeline(self: *Encoder, pipeline: *const Pipeline) !void {
        try self.commands.append(self.allocator, .{
            .bind_pipeline = .{ .pipeline = pipeline.handle },
        });
    }
    fn bindTexture(self: *Encoder, descriptor: GPU.Descriptor, texture: ?*const Texture) !void {
        var handle: ?GPU.Handle = null;
        if (texture) |t| {
            handle = t.handle;
        }
        try self.commands.append(self.allocator, .{
            .bind_texture = .{ .texture = handle, .descriptor = descriptor },
        });
    }
    fn bindBuffer(self: *Encoder, descriptor: GPU.Descriptor, buffer: *const Buffer) !void {
        try self.commands.append(self.allocator, .{
            .bind_buffer = .{ .buffer = buffer.handle, .descriptor = descriptor },
        });
    }
    fn pushU32(self: *Encoder, descriptor: GPU.Descriptor, value: u32) !void {
        try self.commands.append(self.allocator, .{
            .push_u32 = .{ .value = value, .descriptor = descriptor },
        });
    }
    fn pushF32(self: *Encoder, descriptor: GPU.Descriptor, value: f32) !void {
        try self.commands.append(self.allocator, .{
            .push_f32 = .{ .value = value, .descriptor = descriptor },
        });
    }
    fn draw(self: *Encoder, count: u32) !void {
        try self.commands.append(self.allocator, .{
            .draw = .{ .count = count },
        });
    }
    fn drawFullQuad(self: *Encoder) !void {
        try self.draw(3); // Draw full screen triangle
    }
    fn clearColor(self: *Encoder, color: u32) !void {
        try self.commands.append(self.allocator, .{ .clear_color = .{ .color = color } });
    }
    fn clearDepth(self: *Encoder) !void {
        try self.commands.append(self.allocator, .{.clear_depth});
    }
    fn viewport(self: *Encoder, x: i32, y: i32, w: u32, h: u32) !void {
        try self.commands.append(self.allocator, .{ .viewport = .{
            .x = x,
            .y = y,
            .width = w,
            .height = h,
        } });
    }
};

allocator: std.mem.Allocator,
gpu: GPU,
config: *nux.Config,
window: *nux.Window,
mesh: *nux.Mesh,
texture: *nux.Texture,
material: *nux.Material,
staticmesh: *nux.StaticMesh,
transform: *nux.Transform,
font: *nux.Font,
pipelines: struct {
    uber_opaque: nux.GPU.Pipeline,
    uber_line: nux.GPU.Pipeline,
    canvas: nux.GPU.Pipeline,
},
buffers: struct {
    constants: nux.GPU.Buffer,
    batches: nux.GPU.Buffer,
    transforms: nux.GPU.Buffer,
    quads: nux.GPU.Buffer,
    vertices: nux.GPU.Buffer,
},
batches: std.ArrayList(GPU.Batch),
batches_head: usize,
quads_queue: std.ArrayList(GPU.Quad),
quads_head: usize,
vertex_span_allocator: nux.SpanAllocator,
active_batch: GPU.Batch,
active_batch_index: usize,
encoder: Encoder,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.gpu = core.platform.gpu;
    self.allocator = core.platform.allocator;
    self.encoder = .init(self);

    // Create GPU device
    try self.gpu.vtable.create_device(self.gpu.ptr);

    // Create pipelines
    self.pipelines.uber_opaque = try .init(self, .{
        .type = .uber,
        .primitive = .triangles,
        .blend = false,
        .depth_test = true,
    });
    errdefer self.pipelines.uber_opaque.deinit();
    self.pipelines.uber_line = try .init(self, .{
        .type = .uber,
        .primitive = .lines,
        .blend = false,
        .depth_test = true,
    });
    errdefer self.pipelines.uber_line.deinit();
    self.pipelines.canvas = try .init(self, .{
        .type = .canvas,
        .primitive = .triangles,
        .blend = true,
        .depth_test = false,
    });
    errdefer self.pipelines.canvas.deinit();

    // Create buffers
    const default_quad_size = try self.config.getUint(usize, "GPU.defaultQuadBufferSize");
    const quad_queue_size = try self.config.getUint(usize, "GPU.quadQueueSize");
    const default_vertex_buffer_size = try self.config.getUint(usize, "GPU.defaultVertexBufferSize");
    const default_span_capacity = try self.config.getUint(usize, "GPU.defaultVertexBufferSpanCapacity");
    const default_batches_capacity = try self.config.getUint(usize, "GPU.batchesCapacity");
    self.buffers.constants = try .init(self, .constants, @sizeOf(GPU.Constants));
    errdefer self.buffers.constants.deinit();
    self.buffers.vertices = try .init(self, .vertices, default_vertex_buffer_size);
    errdefer self.buffers.vertices.deinit();
    self.buffers.quads = try .init(self, .quads, @sizeOf(GPU.Quad) * default_quad_size);
    errdefer self.buffers.quads.deinit();
    self.buffers.batches = try .init(self, .batches, @sizeOf(GPU.Batch) * default_batches_capacity);
    errdefer self.buffers.batches.deinit();

    // Create transfer buffers
    self.batches_head = 0;
    self.quads_queue = try .initCapacity(self.allocator, quad_queue_size);
    self.quads_head = 0;
    errdefer self.quads_queue.deinit(self.allocator);
    self.vertex_span_allocator = try .init(
        self.allocator,
        default_vertex_buffer_size,
        default_span_capacity,
    );
}
pub fn deinit(self: *Self) void {
    self.encoder.deinit();
    self.vertex_span_allocator.deinit();
    self.quads_queue.deinit(self.allocator);
    self.buffers.batches.deinit();
    self.buffers.quads.deinit();
    self.buffers.vertices.deinit();
    self.buffers.constants.deinit();
    self.pipelines.uber_opaque.deinit();
    self.pipelines.uber_line.deinit();
    self.pipelines.canvas.deinit();
    self.gpu.vtable.delete_device(self.gpu.ptr);
}
pub fn onPostUpdate(self: *Self) !void {
    try self.mesh.syncGPU();
    try self.texture.syncGPU();
    try self.flushQuads();
    self.quads_head = 0;
    self.batches_head = 0;
    self.active_batch_index = 0;
}
fn flushQuads(self: *Self) !void {
    const offset = @sizeOf(GPU.Quad) * self.quads_head;
    const size = @sizeOf(GPU.Quad) * self.quads_queue.items.len;
    try self.buffers.quads.update(offset, size, @ptrCast(self.quads_queue.items));
    self.quads_queue.clearRetainingCapacity();
    self.quads_head += self.quads_queue.items.len;
}
fn pushQuad(self: *Self, box: nux.Box2i, tex: nux.Vec2i, scale: u32) !void {
    if (self.quads_queue.capacity == self.quads_queue.items.len) {
        try self.flushQuads();
    }
    self.quads_queue.appendAssumeCapacity(.{
        .pos = @as(u32, @intCast(box.y())) << 16 | @as(u32, @intCast(box.x())),
        .tex = @as(u32, @intCast(tex.y())) << 16 | @as(u32, @intCast(tex.x())),
        .size = @as(u32, @intCast(box.h())) << 16 | @as(u32, @intCast(box.w())),
        .scale = scale,
    });
    self.active_batch.count += 1;
}
fn beginTexturedBatch(self: *Self, texture_id: nux.ID) !void {

    // Sync texture
    const texture = try self.texture.components.get(texture_id);
    try texture.syncGPU(self);

    // Prepare batch
    self.active_batch = .{
        .mode = 1,
        .first = @intCast(self.quads_head + self.quads_queue.items.len),
        .count = 0,
        .texture_width = texture.info.width,
        .texture_height = texture.info.height,
        .color = .{ 1, 1, 1, 1 },
    };
    self.active_batch_index = self.batches_head;

    // Begin commands
    try self.encoder.bindTexture(.texture, &texture.handle.?);
}
fn beginColoredBatch(self: *Self, color: [4]f32) !void {
    self.active_batch = .{
        .mode = 0,
        .first = @intCast(self.quads_head + self.quads_queue.items.len),
        .count = 0,
        .texture_width = 0,
        .texture_height = 0,
        .color = color,
    };

    self.active_batch_index = self.batches_head;
    try self.encoder.bindTexture(.texture, null);
}
fn endBatch(self: *Self) !void {

    // Draw quads command
    try self.encoder.pushU32(.batch_index, @intCast(self.active_batch_index));
    try self.encoder.draw(self.active_batch.count * 6);

    // Update batch buffer
    try self.buffers.batches.update(
        @sizeOf(GPU.Batch) * self.active_batch_index,
        @sizeOf(GPU.Batch),
        @ptrCast(&self.active_batch),
    );
    self.batches_head += 1;
    self.active_batch_index += 1;
}
pub fn render(self: *Self, cb: *nux.Graphics.CommandBuffer) !void {

    // Update constants
    const constants = GPU.Constants{
        .view = undefined,
        .proj = undefined,
        .screen_size = .{ self.window.width, self.window.height },
        .time = 0,
    };
    try self.buffers.constants.update(0, @sizeOf(GPU.Constants), @ptrCast(&constants));

    // Start canvas pass
    try self.encoder.bindFramebuffer(null);
    try self.encoder.clearColor(0);
    try self.encoder.bindPipeline(&self.pipelines.canvas);
    try self.encoder.viewport(0, 0, self.window.width, self.window.height);
    try self.encoder.bindBuffer(.constants_buffer, &self.buffers.constants);
    try self.encoder.bindBuffer(.batches_buffer, &self.buffers.batches);
    try self.encoder.bindBuffer(.quads_buffer, &self.buffers.quads);

    for (cb.commands.items) |cmd| {
        switch (cmd) {
            .blit => |info| {
                try self.beginTexturedBatch(info.source);
                try self.pushQuad(.init(
                    info.pos.x(),
                    info.pos.y(),
                    info.box.w(),
                    info.box.h(),
                ), .init(
                    info.box.x(),
                    info.box.y(),
                ), info.scale);
                try self.endBatch();
            },
            .rectangle => |info| {
                try self.beginColoredBatch(info.color);
                try self.pushQuad(info.box, .zero(), 1);
                try self.endBatch();
            },
            .text => |info| {
                const font = try self.font.components.get(try self.font.default());

                try self.beginTexturedBatch(font.texture);

                var pos: nux.Vec2i = info.position.as(nux.Vec2i);
                var line_height: u32 = 0;
                var it = font.iterate(cb.dataSlice(info.data));
                while (it.next()) |entry| {
                    const glyph = entry.glyph;

                    // Push quad
                    const quad = nux.Box2i.init(pos.x(), pos.y(), glyph.box.w(), glyph.box.h());
                    try self.pushQuad(quad, glyph.box.pos, info.scale);

                    // Advance text box
                    line_height = @max(line_height, glyph.box.h());
                    pos = pos.add(.init(@as(i32, @intCast((glyph.box.w() + 1) * info.scale)), 0));
                }
                try self.endBatch();
            },
            else => {},
        }
    }
    try self.encoder.submit();
}
pub fn onRender(self: *Self) !void {
    _ = self;

    // const constants: GPU.Constants = .{
    //     .view = undefined,
    //     .proj = undefined,
    //     .screen_size = undefined,
    //     .time = 0,
    // };
    // try self.buffers.constants.update(0, @sizeOf(GPU.Constants), @ptrCast(&constants));
    //
    // try encoder.bindFramebuffer(null);
    // try encoder.viewport(0, 0, self.window.width, self.window.height);
    // try encoder.clearColor(0x0);
    // try encoder.bindPipeline(&self.pipelines.uber_line);
    // try encoder.bindBuffer(.constants_buffer, &self.buffers.constants);
    // // try encoder.bindBuffer(.batches_buffer, &self.buffers.batches);
    // // try encoder.bindBuffer(.transforms_buffer, &self.buffers.transforms);
    // try encoder.bindBuffer(.vertices_buffer, &self.mesh.vertex_buffer);
    //
    // // var it = self.staticmesh.components.iterator();
    // // while (it.next()) |entry| {}
    //
    // try encoder.submit();
}
