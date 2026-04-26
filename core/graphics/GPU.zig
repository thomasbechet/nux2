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
    size: usize,

    pub fn init(gpu: *Self, typ: GPU.BufferType, size: u32) !Buffer {
        return .{
            .gpu = gpu,
            .handle = try gpu.gpu.vtable.create_buffer(gpu.gpu.ptr, typ, size),
            .size = size,
        };
    }
    pub fn deinit(self: *Buffer) void {
        self.gpu.gpu.vtable.delete_buffer(self.gpu.gpu.ptr, self.handle);
    }
    pub fn update(self: *Buffer, offset: usize, size: usize, data: []const u8) !void {
        try self.gpu.gpu.vtable.update_buffer(
            self.gpu.gpu.ptr,
            self.handle,
            @intCast(offset),
            @intCast(size),
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
            .type = .bind_framebuffer,
            .data = .{ .bind_framebuffer = .{ .framebuffer = handle } },
        });
    }
    fn bindPipeline(self: *Encoder, pipeline: *const Pipeline) !void {
        try self.commands.append(self.allocator, .{
            .type = .bind_pipeline,
            .data = .{ .bind_pipeline = .{ .pipeline = pipeline.handle } },
        });
    }
    fn bindTexture(self: *Encoder, descriptor: GPU.Descriptor, texture: ?*const Texture) !void {
        var handle: ?GPU.Handle = null;
        if (texture) |t| {
            handle = t.handle;
        }
        try self.commands.append(self.allocator, .{
            .type = .bind_texture,
            .data = .{ .bind_texture = .{ .texture = handle, .descriptor = descriptor } },
        });
    }
    fn bindBuffer(self: *Encoder, descriptor: GPU.Descriptor, buffer: *const Buffer) !void {
        try self.commands.append(self.allocator, .{
            .type = .bind_buffer,
            .data = .{ .bind_buffer = .{ .buffer = buffer.handle, .descriptor = descriptor } },
        });
    }
    fn pushU32(self: *Encoder, descriptor: GPU.Descriptor, value: u32) !void {
        try self.commands.append(self.allocator, .{
            .type = .push_u32,
            .data = .{ .push_u32 = .{ .value = value, .descriptor = descriptor } },
        });
    }
    fn pushF32(self: *Encoder, descriptor: GPU.Descriptor, value: f32) !void {
        try self.commands.append(self.allocator, .{
            .type = .push_f32,
            .data = .{ .push_f32 = .{ .value = value, .descriptor = descriptor } },
        });
    }
    fn draw(self: *Encoder, count: u32) !void {
        try self.commands.append(self.allocator, .{
            .type = .draw,
            .data = .{ .draw = .{ .count = count } },
        });
    }
    fn drawFullQuad(self: *Encoder) !void {
        try self.draw(3); // Draw full screen triangle
    }
    fn clearColor(self: *Encoder, color: u32) !void {
        try self.commands.append(self.allocator, .{
            .type = .clear_color,
            .data = .{ .clear_color = .{ .color = color } },
        });
    }
    fn clearDepth(self: *Encoder) !void {
        try self.commands.append(self.allocator, .{
            .type = .clear_depth,
        });
    }
    fn viewport(self: *Encoder, x: i32, y: i32, w: u32, h: u32) !void {
        try self.commands.append(self.allocator, .{
            .type = .viewport,
            .data = .{ .viewport = .{
                .x = x,
                .y = y,
                .width = w,
                .height = h,
            } },
        });
    }
};

fn QueueBuffer(T: type) type {
    return struct {
        queue: []T,
        queue_size: usize,
        buffer: Buffer,
        buffer_head: usize,
        buffer_start: usize, // Next index for upload

        fn init(
            gpu: *Self,
            buffer_type: GPU.BufferType,
            buffer_size: usize,
            queue_size: usize,
        ) !@This() {
            return .{
                .queue = try gpu.allocator.alloc(T, queue_size),
                .queue_size = 0,
                .buffer = try .init(gpu, buffer_type, @intCast(@sizeOf(T) * buffer_size)),
                .buffer_head = 0,
                .buffer_start = 0,
            };
        }
        fn deinit(self: *@This()) void {
            self.buffer.gpu.allocator.free(self.queue);
            self.buffer.deinit();
        }
        fn push(self: *@This(), value: T) !void {
            if (self.buffer_head >= self.buffer.size) {
                return error.OutOfMemoryGPU;
            }

            // Flush
            if (self.queue_size >= self.queue.len) {
                try self.flush();
            }

            // Push element
            self.queue[self.queue_size] = value;
            self.queue_size += 1;
            self.buffer_head += 1;
        }
        fn flush(self: *@This()) !void {
            try self.buffer.update(
                @sizeOf(T) * self.buffer_start,
                @sizeOf(T) * self.queue_size,
                @ptrCast(self.queue),
            );
            self.buffer_start += self.queue_size;
            self.queue_size = 0;
        }
        fn reset(self: *@This()) void {
            self.buffer_head = 0;
            self.buffer_start = 0;
            self.queue_size = 0;
        }
    };
}

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
    uber_opaque: Pipeline,
    uber_line: Pipeline,
    canvas: Pipeline,
},
buffers: struct {
    constants: Buffer,
    transforms: Buffer,
    vertices: Buffer,
},
batches: QueueBuffer(GPU.Batch),
quads: QueueBuffer(GPU.Quad),
vertex_span_allocator: nux.SpanAllocator,
active_batch: GPU.Batch,
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
    const quad_buffer_size = try self.config.getUint(u32, "GPU.quadBufferSize");
    const quad_queue_size = try self.config.getUint(u32, "GPU.quadQueueSize");
    const batch_buffer_size = try self.config.getUint(u32, "GPU.batchBufferSize");
    const batch_queue_size = try self.config.getUint(u32, "GPU.batchQueueSize");
    const vertex_buffer_size = try self.config.getUint(u32, "GPU.vertexBufferSize");
    const vertex_span_size = try self.config.getUint(u32, "GPU.vertexSpanSize");

    self.buffers.constants = try .init(self, .constants, @sizeOf(GPU.Constants));
    errdefer self.buffers.constants.deinit();
    self.buffers.vertices = try .init(self, .vertices, vertex_buffer_size);
    errdefer self.buffers.vertices.deinit();
    self.batches = try .init(self, .batches, batch_buffer_size, batch_queue_size);
    errdefer self.batches.deinit();
    self.quads = try .init(self, .quads, quad_buffer_size, quad_queue_size);
    errdefer self.quads.deinit();

    self.vertex_span_allocator = try .init(
        self.allocator,
        vertex_buffer_size,
        vertex_span_size,
    );
}
pub fn deinit(self: *Self) void {
    self.encoder.deinit();
    self.vertex_span_allocator.deinit();
    self.quads.deinit();
    self.batches.deinit();
    self.buffers.vertices.deinit();
    self.buffers.constants.deinit();
    self.pipelines.uber_opaque.deinit();
    self.pipelines.uber_line.deinit();
    self.pipelines.canvas.deinit();
    self.gpu.vtable.delete_device(self.gpu.ptr);
}
fn pushQuad(self: *Self, box: nux.Box2i, tex: nux.Vec2i, scale: u32) !void {
    try self.quads.push(.{
        .pos = @as(u32, @intCast(box.y())) << 16 | @as(u32, @intCast(box.x())),
        .tex = @as(u32, @intCast(tex.y())) << 16 | @as(u32, @intCast(tex.x())),
        .size = @as(u32, @intCast(box.h())) << 16 | @as(u32, @intCast(box.w())),
        .scale = scale,
    });
    self.active_batch.count += 1;
}
fn beginTexturedBatch(self: *Self, texture_id: nux.ID, color: nux.Color) !void {

    // Sync texture
    const texture = try self.texture.components.get(texture_id);
    try texture.syncGPU(self);

    // Prepare batch
    self.active_batch = .{
        .mode = 1,
        .first = @intCast(self.quads.buffer_head),
        .count = 0,
        .texture_width = texture.info.width,
        .texture_height = texture.info.height,
        .color = color.rgba.data,
    };

    // Begin commands
    try self.encoder.bindTexture(.texture, &texture.handle.?);
}
fn beginColoredBatch(self: *Self, color: nux.Color) !void {
    self.active_batch = .{
        .mode = 0,
        .first = @intCast(self.quads.buffer_head),
        .count = 0,
        .texture_width = 0,
        .texture_height = 0,
        .color = color.rgba.data,
    };

    // Begin commands
    try self.encoder.bindTexture(.texture, null);
}
fn endBatch(self: *Self) !void {
    // Draw quads command
    try self.encoder.pushU32(.batch_index, @intCast(self.batches.buffer_head));
    try self.encoder.draw(self.active_batch.count * 6);

    // Push batch buffer
    try self.batches.push(self.active_batch);
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
    try self.encoder.bindBuffer(.batches_buffer, &self.batches.buffer);
    try self.encoder.bindBuffer(.quads_buffer, &self.quads.buffer);

    for (cb.commands.items) |cmd| {
        switch (cmd) {
            .blit => |info| {
                try self.beginTexturedBatch(info.source, .white);
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

                try self.beginTexturedBatch(font.texture, info.color);

                var pos: nux.Vec2i = info.position.as(nux.Vec2i);
                var line_height: u32 = 0;
                const text = cb.dataSlice(info.data);
                var it = font.iterate(text);
                while (it.next()) |entry| {
                    const glyph = entry.glyph;

                    // Push quad
                    const quad = nux.Box2i.init(
                        pos.x(),
                        pos.y(),
                        glyph.box.w(),
                        glyph.box.h(),
                    );
                    try self.pushQuad(quad, glyph.box.pos, info.scale);

                    // Advance text box
                    line_height = @max(line_height, glyph.box.h());
                    const advance = (glyph.box.w() + 1) * info.scale;
                    pos = pos.add(.init(@intCast(advance), 0));
                }

                try self.endBatch();
            },
            else => {},
        }
    }

    // Upload buffers
    try self.mesh.syncGPU();
    try self.texture.syncGPU();
    try self.batches.flush();
    try self.quads.flush();
    self.batches.reset();
    self.quads.reset();

    // Submit gpu commands
    try self.encoder.submit();
}
