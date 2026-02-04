const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque,
vtable: *const VTable,

pub const Handle = *anyopaque;

pub const TextureInfo = struct {};

pub const VTable = struct {
    create_texture: *const fn (*anyopaque, info: TextureInfo) anyerror!Handle,
    delete_texture: *const fn (*anyopaque, handle: Handle) anyerror!void,
    update_texture: *const fn (*anyopaque, x: u32, y: u32, w: u32, h: u32, data: []const u8) anyerror!void,
};

const Default = struct {
    const GPUHandle = struct {};
    fn createTexture(_: *anyopaque, _: TextureInfo) anyerror!Handle {
        var handle = GPUHandle{};
        return &handle;
    }
    fn deleteTexture(_: *anyopaque, _: Handle) anyerror!void {}
    fn updateTexture(_: *anyopaque, x: u32, y: u32, w: u32, h: u32, data: []const u8) anyerror!void {
        _ = x;
        _ = y;
        _ = w;
        _ = h;
        _ = data;
    }
};

pub const default: @This() = .{ .ptr = undefined, .vtable = &.{
    .create_texture = Default.createTexture,
    .delete_texture = Default.deleteTexture,
    .update_texture = Default.updateTexture,
} };
