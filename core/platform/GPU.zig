const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

pub const Handle = *anyopaque;

pub const Command = union(enum) {
    bind_framebuffer: struct {
        framebuffer: ?Handle, // null for default framebuffer
    },
    bind_pipeline: struct {
        pipeline: Handle,
    },
    bind_buffer: struct {
        buffer: Handle,
        descriptor: nux.GPU.Descriptor,
    },
    bind_texture: struct {
        texture: Handle,
        descriptor: nux.GPU.Descriptor,
    },
    push_u32: struct {
        value: u32,
        descriptor: nux.GPU.Descriptor,
    },
    push_f32: struct {
        value: f32,
        descriptor: nux.GPU.Descriptor,
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
    create_device: *const fn (*anyopaque) anyerror!void = Default.createDevice,
    delete_device: *const fn (*anyopaque) void = Default.deleteDevice,
    create_pipeline: *const fn (*anyopaque, info: nux.GPU.PipelineInfo) anyerror!Handle = Default.createPipeline,
    delete_pipeline: *const fn (*anyopaque, handle: Handle) void = Default.deletePipeline,
    create_framebuffer: *const fn (*anyopaque, texture: Handle) anyerror!Handle = Default.createFramebuffer,
    delete_framebuffer: *const fn (*anyopaque, handle: Handle) void = Default.deleteFramebuffer,
    create_texture: *const fn (*anyopaque, info: nux.GPU.TextureInfo) anyerror!Handle = Default.createTexture,
    delete_texture: *const fn (*anyopaque, handle: Handle) void = Default.deleteTexture,
    update_texture: *const fn (*anyopaque, handle: Handle, x: u32, y: u32, w: u32, h: u32, data: []const u8) anyerror!void = Default.updateTexture,
    create_buffer: *const fn (*anyopaque, type: nux.GPU.BufferType, size: usize) anyerror!Handle = Default.createBuffer,
    delete_buffer: *const fn (*anyopaque, handle: Handle) void = Default.deleteBuffer,
    update_buffer: *const fn (*anyopaque, handle: Handle, offset: u64, size: u64, data: []const f32) anyerror!void = Default.updateBuffer,
    submit_commands: *const fn (*anyopaque, commands: []const Command) anyerror!void = Default.submitCommands,
};

const Default = struct {
    const GPUHandle = struct {};
    fn createDevice(_: *anyopaque) anyerror!void {}
    fn deleteDevice(_: *anyopaque) void {}
    fn createPipeline(_: *anyopaque, _: nux.GPU.PipelineInfo) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deletePipeline(_: *anyopaque, _: Handle) void {}
    fn createFramebuffer(_: *anyopaque, _: Handle) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deleteFramebuffer(_: *anyopaque, _: Handle) void {}
    fn createTexture(_: *anyopaque, _: nux.GPU.TextureInfo) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deleteTexture(_: *anyopaque, _: Handle) void {}
    fn updateTexture(_: *anyopaque, _: Handle, _: u32, _: u32, _: u32, _: u32, _: []const u8) anyerror!void {}
    fn createBuffer(_: *anyopaque, _: nux.GPU.BufferType, _: u64) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deleteBuffer(_: *anyopaque, _: Handle) void {}
    fn updateBuffer(_: *anyopaque, _: Handle, _: u64, _: u64, _: []const f32) anyerror!void {}
    fn submitCommands(_: *anyopaque, _: []const Command) anyerror!void {}
};
