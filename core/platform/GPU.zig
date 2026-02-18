const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

pub const Handle = *anyopaque;

pub const TextureInfo = struct {
    width: u32 = 0,
    height: u32 = 0,
};

pub const VTable = struct {
    create_texture: *const fn (*anyopaque, info: TextureInfo) anyerror!Handle = Default.createTexture,
    delete_texture: *const fn (*anyopaque, handle: Handle) anyerror!void = Default.deleteTexture,
    update_texture: *const fn (*anyopaque, handle: Handle, x: u32, y: u32, w: u32, h: u32, data: []const u8) anyerror!void = Default.updateTexture,
};

const Default = struct {
    const GPUHandle = struct {};
    fn createTexture(_: *anyopaque, _: TextureInfo) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deleteTexture(_: *anyopaque, _: Handle) anyerror!void {}
    fn updateTexture(_: *anyopaque, _: Handle, _: u32, _: u32, _: u32, _: u32, _: []const u8) anyerror!void {}
};
