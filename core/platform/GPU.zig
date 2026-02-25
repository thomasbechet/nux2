const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

pub const Handle = *anyopaque;

pub const TextureFiltering = enum(u32) {
    nearest = 0,
    linear = 1,
};

pub const TextureType = enum(u32) {
    image_rgba = 0,
    image_indexed = 1,
    render_target = 2,
};

pub const TextureInfo = struct {
    width: u32 = 0,
    height: u32 = 0,
    filter: TextureFiltering = .nearest,
    type: TextureType = .image_rgba,
};

pub const BufferType = enum(u32) {
    uniform = 0,
    storage = 1,
};

pub const VTable = struct {
    create_texture: *const fn (*anyopaque, info: TextureInfo) anyerror!Handle = Default.createTexture,
    delete_texture: *const fn (*anyopaque, handle: Handle) void = Default.deleteTexture,
    update_texture: *const fn (*anyopaque, handle: Handle, x: u32, y: u32, w: u32, h: u32, data: []const u8) anyerror!void = Default.updateTexture,
    create_buffer: *const fn (*anyopaque, type: BufferType, size: usize) anyerror!Handle = Default.createBuffer,
    delete_buffer: *const fn (*anyopaque, handle: Handle) void = Default.deleteBuffer,
    update_buffer: *const fn (*anyopaque, handle: Handle, offset: u64, size: u64, data: []const f32) anyerror!void = Default.updateBuffer,
};

const Default = struct {
    const GPUHandle = struct {};
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
};
