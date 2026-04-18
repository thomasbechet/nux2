const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

pub const Handle = *anyopaque;

pub const Constants = extern struct {
    view: [16]f32, // 0
    proj: [16]f32, // 4
    screen_size: [2]u32, // 8
    time: f32,
    _pad0: u32 = undefined,
};

pub const Quad = extern struct {
    pos: u32, // 0
    tex: u32,
    size: u32,
    scale: u32,
};

pub const Batch = extern struct {
    mode: u32, // 0
    first: u32,
    count: u32,
    texture_width: u32,
    texture_height: u32, // 1
    _pad0: [3]u32 = undefined,
    color: [4]f32, // 2
    _pad1: [4]u32 = undefined, // 3
};

pub const SceneBatch = extern struct {
    vertex_offset: u32,
    vertex_attributes: u32,
    transform_offset: u32,
    has_texture: u32,
    color: [4]f32,
};

pub const BufferType = enum(u32) {
    constants = 0,
    batches = 1,
    quads = 2,
    transforms = 3,
    vertices = 4,
};

pub const PipelineType = enum(u32) {
    uber = 0,
    canvas = 1,
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

pub const CommandType = enum(u32) {
    bind_framebuffer = 0,
    bind_pipeline = 1,
    bind_buffer = 2,
    bind_texture = 3,
    push_u32 = 4,
    push_f32 = 5,
    draw = 6,
    clear_color = 7,
    clear_depth = 8,
    viewport = 9,
};

pub const Command = extern struct {
    type: CommandType,
    data: extern union {
        bind_framebuffer: extern struct {
            framebuffer: ?Handle, // null for default framebuffer
        },
        bind_pipeline: extern struct {
            pipeline: Handle,
        },
        bind_buffer: extern struct {
            buffer: Handle,
            descriptor: Descriptor,
        },
        bind_texture: extern struct {
            texture: ?Handle,
            descriptor: Descriptor,
        },
        push_u32: extern struct {
            value: u32,
            descriptor: Descriptor,
        },
        push_f32: extern struct {
            value: f32,
            descriptor: Descriptor,
        },
        draw: extern struct {
            count: u32,
        },
        clear_color: extern struct {
            color: u32,
        },
        viewport: extern struct {
            x: i32,
            y: i32,
            width: u32,
            height: u32,
        },
    },
};

pub const VTable = struct {
    create_device: *const fn (*anyopaque) anyerror!void = Default.createDevice,
    delete_device: *const fn (*anyopaque) void = Default.deleteDevice,
    create_pipeline: *const fn (*anyopaque, info: PipelineInfo) anyerror!Handle = Default.createPipeline,
    delete_pipeline: *const fn (*anyopaque, handle: Handle) void = Default.deletePipeline,
    create_framebuffer: *const fn (*anyopaque, texture: Handle) anyerror!Handle = Default.createFramebuffer,
    delete_framebuffer: *const fn (*anyopaque, handle: Handle) void = Default.deleteFramebuffer,
    create_texture: *const fn (*anyopaque, info: TextureInfo) anyerror!Handle = Default.createTexture,
    delete_texture: *const fn (*anyopaque, handle: Handle) void = Default.deleteTexture,
    update_texture: *const fn (*anyopaque, handle: Handle, x: u32, y: u32, w: u32, h: u32, data: []const u8) anyerror!void = Default.updateTexture,
    create_buffer: *const fn (*anyopaque, type: BufferType, size: u32) anyerror!Handle = Default.createBuffer,
    delete_buffer: *const fn (*anyopaque, handle: Handle) void = Default.deleteBuffer,
    update_buffer: *const fn (*anyopaque, handle: Handle, offset: u32, size: u32, data: []const u8) anyerror!void = Default.updateBuffer,
    submit_commands: *const fn (*anyopaque, commands: []const Command) anyerror!void = Default.submitCommands,
};

const Default = struct {
    const GPUHandle = struct {};
    fn createDevice(_: *anyopaque) anyerror!void {}
    fn deleteDevice(_: *anyopaque) void {}
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
    fn createBuffer(_: *anyopaque, _: BufferType, _: u32) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deleteBuffer(_: *anyopaque, _: Handle) void {}
    fn updateBuffer(_: *anyopaque, _: Handle, _: u32, _: u32, _: []const u8) anyerror!void {}
    fn submitCommands(_: *anyopaque, _: []const Command) anyerror!void {}
};
