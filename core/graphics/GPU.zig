const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Platform = nux.Platform.GPU;

pub const TextureType = enum(u32) {
    image_rgba = 0,
    image_indexed = 1,
    render_target = 2,
};

pub const BufferType = enum(u32) {
    uniform = 0,
    storage = 1,
};

pub const PipelineType = enum(u32) {
    uber = 0,
    canvas = 1,
    blit = 2,
};

pub const TextureFiltering = enum(u32) {
    nearest = 0,
    linear = 1,
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
    filter: TextureFiltering = .nearest,
    type: TextureType = .image_rgba,
};

pub const Framebuffer = struct {
    handle: Platform.Handle,
};

pub const Pipeline = struct {
    handle: Platform.Handle,
    gpu: *Self,

    pub fn deinit(self: *Pipeline) void {
        self.gpu.platform.vtable.delete_pipeline(self.gpu.platform.ptr, self.handle);
    }
};

pub const Texture = struct {
    handle: Platform.Handle,
    gpu: *Self,
};

pub const Buffer = struct {
    handle: Platform.Handle,
};

const Encoder = struct {
    commands: std.ArrayList(Platform.Command),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Encoder {
        return .{
            .allocator = allocator,
            .commands = .empty,
        };
    }
    pub fn deinit(self: *Encoder) void {
        self.commands.deinit(self.allocator);
    }

    pub fn bindFramebuffer(self: *Encoder, framebuffer: *const Framebuffer) !void {
        try self.commands.append(self.allocator, .{
            .bind_framebuffer = .{ .framebuffer = framebuffer.handle },
        });
    }
    pub fn bindPipeline(self: *Encoder, pipeline: *const Pipeline) !void {
        try self.commands.append(self.allocator, .{
            .bind_pipeline = .{ .pipeline = pipeline.handle },
        });
    }
    pub fn bindTexture(self: *Encoder, descriptor: Platform.Descriptor, texture: *const Texture) !void {
        try self.commands.append(self.allocator, .{
            .bind_texture = .{ .texture = texture.handle, .descriptor = descriptor },
        });
    }
    pub fn bindBuffer(self: *Encoder, descriptor: Platform.Descriptor, buffer: *const Buffer) !void {
        try self.commands.append(self.allocator, .{
            .bind_buffer = .{ .buffer = buffer.handle, .descriptor = descriptor },
        });
    }
    pub fn pushU32(self: *Encoder, descriptor: Platform.Descriptor, value: u32) !void {
        try self.commands.append(self.allocator, .{
            .push_u32 = .{ .value = value, .descriptor = descriptor },
        });
    }
    pub fn pushF32(self: *Encoder, descriptor: Platform.Descriptor, value: f32) !void {
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
};

platform: Platform,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.platform = core.platform.gpu;
}

pub fn createPipeline(self: *Self, info: Platform.PipelineInfo) !Pipeline {
    return .{
        .handle = try self.platform.vtable.create_pipeline(self.platform.ptr, info),
    };
}
pub fn submitCommands(self: *Self, encoder: *Encoder) !void {
    try self.platform.vtable.submit_commands(self.platform.ptr, encoder.commands.items);
    encoder.commands.clearRetainingCapacity();
}
