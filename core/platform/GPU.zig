const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

pub const Handle = *anyopaque;

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

pub const Command = union(enum) {
    bind_framebuffer: struct {
        framebuffer: ?Handle, // null for default framebuffer
    },
    bind_pipeline: struct {
        pipeline: Handle,
    },
    bind_buffer: struct {
        buffer: Handle,
        descriptor: Descriptor,
    },
    bind_texture: struct {
        texture: Handle,
        descriptor: Descriptor,
    },
    push_u32: struct {
        value: u32,
        descriptor: Descriptor,
    },
    push_f32: struct {
        value: f32,
        descriptor: Descriptor,
    },
    draw: struct {
        count: u32,
    },
    clear_color: struct {
        color: u32,
    },
    clear_depth,
    viewport: struct {
        x: i32,
        y: i32,
        width: u32,
        height: u32,
    },
};

pub const VTable = struct {
    create_pipeline: *const fn (*anyopaque, info: PipelineInfo) anyerror!Handle = Default.createPipeline,
    delete_pipeline: *const fn (*anyopaque, handle: Handle) void = Default.deletePipeline,
    create_framebuffer: *const fn (*anyopaque, texture: Handle) anyerror!Handle = Default.createFramebuffer,
    delete_framebuffer: *const fn (*anyopaque, handle: Handle) void = Default.deleteFramebuffer,
    create_texture: *const fn (*anyopaque, info: TextureInfo) anyerror!Handle = Default.createTexture,
    delete_texture: *const fn (*anyopaque, handle: Handle) void = Default.deleteTexture,
    update_texture: *const fn (*anyopaque, handle: Handle, x: u32, y: u32, w: u32, h: u32, data: []const u8) anyerror!void = Default.updateTexture,
    create_buffer: *const fn (*anyopaque, type: BufferType, size: usize) anyerror!Handle = Default.createBuffer,
    delete_buffer: *const fn (*anyopaque, handle: Handle) void = Default.deleteBuffer,
    update_buffer: *const fn (*anyopaque, handle: Handle, offset: u64, size: u64, data: []const f32) anyerror!void = Default.updateBuffer,
    submit_commands: *const fn (*anyopaque, commands: []const Command) anyerror!void = Default.submitCommands,
};

const Default = struct {
    const GPUHandle = struct {};
    fn createPipeline(_: *anyopaque, _: PipelineInfo) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deletePipeline(_: *anyopaque, _: Handle) void {}
    fn createFramebuffer(_: *anyopaque, _: Handle) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deleteFramebuffer(_: *anyopaque, _: Handle) void {}
    fn createTexture(_: *anyopaque, _: TextureInfo) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deleteTexture(_: *anyopaque, _: Handle) void {}
    fn updateTexture(_: *anyopaque, _: Handle, _: u32, _: u32, _: u32, _: u32, _: []const u8) anyerror!void {}
    fn createBuffer(_: *anyopaque, _: BufferType, _: u64) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deleteBuffer(_: *anyopaque, _: Handle) void {}
    fn updateBuffer(_: *anyopaque, _: Handle, _: u64, _: u64, _: []const f32) anyerror!void {}
    fn submitCommands(_: *anyopaque, _: []const Command) anyerror!void {}
};
