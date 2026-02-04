const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque,
vtable: *const VTable,

pub const Handle = *anyopaque;

pub const Event = struct { width: u32, height: u32 };

pub const VTable = struct {
    open: *const fn (*anyopaque, w: u32, h: u32) anyerror!Handle,
    close: *const fn (*anyopaque, handle: Handle) void,
};

const Default = struct {
    const WindowHandle = struct {};
    fn open(_: *anyopaque, w: u32, h: u32) anyerror!Handle {
        _ = w;
        _ = h;
        var handle = WindowHandle{};
        return &handle;
    }
    fn close(_: *anyopaque, handle: Handle) void {
        _ = handle;
    }
};
pub const default: @This() = .{ .ptr = undefined, .vtable = &.{
    .open = Default.open,
    .close = Default.close,
} };
