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
    fn bindTexture(self: *Encoder, descriptor: GPU.Descriptor, texture: *const Texture) !void {
        try self.commands.append(self.allocator, .{
            .bind_texture = .{ .texture = texture.handle, .descriptor = descriptor },
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

gpu: GPU,
allocator: std.mem.Allocator,
window: *nux.Window,
mesh: *nux.Mesh,
texture: *nux.Texture,
material: *nux.Material,
staticmesh: *nux.StaticMesh,
transform: *nux.Transform,
pipelines: struct {
    uber_opaque: nux.GPU.Pipeline,
    uber_line: nux.GPU.Pipeline,
    canvas: nux.GPU.Pipeline,
    blit: nux.GPU.Pipeline,
},
buffers: struct {
    constants: nux.GPU.Buffer,
    batches: nux.GPU.Buffer,
    transforms: nux.GPU.Buffer,
},

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.gpu = core.platform.gpu;
    self.allocator = core.platform.allocator;

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
    self.pipelines.blit = try .init(self, .{
        .type = .blit,
        .primitive = .triangles,
        .blend = true,
        .depth_test = false,
    });
    errdefer self.pipelines.blit.deinit();

    // Create buffers
    self.buffers.constants = try .init(self, .constants, @sizeOf(GPU.Constants));
    errdefer self.buffers.constants.deinit();
}
pub fn deinit(self: *Self) void {
    self.buffers.constants.deinit();
    self.pipelines.uber_opaque.deinit();
    self.pipelines.uber_line.deinit();
    self.pipelines.canvas.deinit();
    self.pipelines.blit.deinit();
    self.gpu.vtable.delete_device(self.gpu.ptr);
}
pub fn onPostUpdate(self: *Self) !void {
    try self.mesh.syncGPU();
    try self.texture.syncGPU();
}
pub fn render(self: *Self, cb: *nux.Graphics.CommandBuffer) !void {
    for (cb.commands.items) |cmd| {
        switch (cmd) {
            .blit => |info| {
                const node = try self.texture.components.get(info.source);
                var encoder = nux.GPU.Encoder.init(self);
                defer encoder.deinit();
                try encoder.bindFramebuffer(null);
                try encoder.viewport(
                    @intFromFloat(info.pos.data[0]),
                    @intFromFloat(info.pos.data[1]),
                    @intFromFloat(info.box.size[0]),
                    @intFromFloat(info.box.size[1]),
                );
                try encoder.bindPipeline(&self.pipelines.blit);
                if (node.handle == null) {
                    node.handle = try .init(self, node.info);
                }
                try encoder.bindTexture(.texture, &node.handle.?);
                try encoder.pushU32(.texture_width, node.info.width);
                try encoder.pushU32(.texture_height, node.info.height);
                try encoder.drawFullQuad();
                try encoder.submit();
            },
            else => {},
        }
    }
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
