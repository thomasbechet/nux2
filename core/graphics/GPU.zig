const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Platform = nux.Platform.GPU;

pub const BufferType = enum(u32) {
    uniform = 0,
    storage = 1,
};

pub const PipelineType = enum(u32) {
    uber = 0,
    canvas = 1,
    blit = 2,
};

pub const Descriptor = enum(u32) {
    constants_buffer = 0,
    batches_buffer = 1,
    transforms_buffer = 2,
    vertices_buffer = 3,
    quads_buffer = 4,
    batch_index = 5,
    texture = 6,
    texture_width = 7,
    texture_height = 8,

    pub const max: usize = 9;
};

pub const PipelineInfo = struct {
    type: PipelineType,
    primitive: nux.Vertex.Primitive = .triangles,
    blend: bool = false,
    depth_test: bool = true,
};

pub const TextureInfo = struct {
    width: u32 = 0,
    height: u32 = 0,
    filter: nux.Texture.Filtering = .nearest,
    type: nux.Texture.Type = .image_rgba,
};

pub const Framebuffer = struct {
    handle: Platform.Handle,
    gpu: *Self,
};

pub const Pipeline = struct {
    handle: Platform.Handle,
    gpu: *Self,

    pub fn init(gpu: *Self, info: PipelineInfo) !Pipeline {
        return .{
            .handle = try gpu.platform.vtable.create_pipeline(gpu.platform.ptr, info),
            .gpu = gpu,
        };
    }
    pub fn deinit(self: *Pipeline) void {
        self.gpu.platform.vtable.delete_pipeline(self.gpu.platform.ptr, self.handle);
    }
};

pub const Texture = struct {
    handle: Platform.Handle,
    gpu: *Self,

    pub fn init(gpu: *Self, info: TextureInfo) !Texture {
        return .{
            .handle = try gpu.platform.vtable.create_texture(gpu.platform.ptr, info),
            .gpu = gpu,
        };
    }
    pub fn deinit(self: *Texture) void {
        self.gpu.platform.vtable.delete_texture(self.gpu.platform.ptr, self.handle);
    }
    pub fn update(self: *Texture, x: u32, y: u32, w: u32, h: u32, data: []const u8) !void {
        try self.gpu.platform.vtable.update_texture(self.gpu.platform.ptr, self.handle, x, y, w, h, data);
    }
};

pub const Buffer = struct {
    handle: Platform.Handle,
    gpu: *Self,

    pub fn init(gpu: *Self, typ: BufferType, size: u64) !Buffer {
        return .{
            .gpu = gpu,
            .handle = try gpu.platform.vtable.create_buffer(gpu.platform.ptr, typ, size),
        };
    }
    pub fn deinit(self: *Buffer) void {
        self.gpu.platform.vtable.delete_buffer(self.gpu.platform.ptr, self.handle);
    }
    pub fn update(self: *Buffer, offset: u64, size: u64, data: []const f32) !void {
        try self.gpu.platform.vtable.update_buffer(self.gpu.platform.ptr, self.handle, offset, size, data);
    }
};

pub const Encoder = struct {
    gpu: *Self,
    allocator: std.mem.Allocator,
    commands: std.ArrayList(Platform.Command),

    pub fn init(gpu: *Self) Encoder {
        return .{
            .gpu = gpu,
            .allocator = gpu.allocator,
            .commands = .empty,
        };
    }
    pub fn deinit(self: *Encoder) void {
        self.commands.deinit(self.gpu.allocator);
    }
    pub fn submit(self: *Encoder) !void {
        try self.gpu.platform.vtable.submit_commands(self.gpu.platform.ptr, self.commands.items);
        self.commands.clearRetainingCapacity();
    }

    pub fn bindFramebuffer(self: *Encoder, framebuffer: ?*const Framebuffer) !void {
        var handle: ?Platform.Handle = null;
        if (framebuffer) |fb| {
            handle = fb.handle;
        }
        try self.commands.append(self.allocator, .{
            .bind_framebuffer = .{ .framebuffer = handle },
        });
    }
    pub fn bindPipeline(self: *Encoder, pipeline: *const Pipeline) !void {
        try self.commands.append(self.allocator, .{
            .bind_pipeline = .{ .pipeline = pipeline.handle },
        });
    }
    pub fn bindTexture(self: *Encoder, descriptor: Descriptor, texture: *const Texture) !void {
        try self.commands.append(self.allocator, .{
            .bind_texture = .{ .texture = texture.handle, .descriptor = descriptor },
        });
    }
    pub fn bindBuffer(self: *Encoder, descriptor: Descriptor, buffer: *const Buffer) !void {
        try self.commands.append(self.allocator, .{
            .bind_buffer = .{ .buffer = buffer.handle, .descriptor = descriptor },
        });
    }
    pub fn pushU32(self: *Encoder, descriptor: Descriptor, value: u32) !void {
        try self.commands.append(self.allocator, .{
            .push_u32 = .{ .value = value, .descriptor = descriptor },
        });
    }
    pub fn pushF32(self: *Encoder, descriptor: Descriptor, value: f32) !void {
        try self.commands.append(self.allocator, .{
            .push_f32 = .{ .value = value, .descriptor = descriptor },
        });
    }
    pub fn draw(self: *Encoder, count: u32) !void {
        try self.commands.append(self.allocator, .{
            .draw = .{ .count = count },
        });
    }
    pub fn drawFullQuad(self: *Encoder) !void {
        try self.draw(3); // Draw full screen triangle
    }
    pub fn clearColor(self: *Encoder, color: u32) !void {
        try self.commands.append(self.allocator, .{ .clear_color = .{ .color = color } });
    }
    pub fn clearDepth(self: *Encoder) !void {
        try self.commands.append(self.allocator, .{.clear_depth});
    }
    pub fn viewport(self: *Encoder, x: i32, y: i32, w: u32, h: u32) !void {
        try self.commands.append(self.allocator, .{ .viewport = .{
            .x = x,
            .y = y,
            .width = w,
            .height = h,
        } });
    }
};

platform: Platform,
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.platform = core.platform.gpu;
    self.allocator = core.platform.allocator;
    try self.platform.vtable.create_device(self.platform.ptr);
}
pub fn deinit(self: *Self) void {
    self.platform.vtable.delete_device(self.platform.ptr);
}
