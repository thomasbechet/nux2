const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

pub const Handle = *anyopaque;

pub const Event = struct { width: u32, height: u32 };

pub const VTable = struct {
    open: *const fn (*anyopaque, w: u32, h: u32) anyerror!Handle = Default.open,
    close: *const fn (*anyopaque, handle: Handle) void = Default.close,
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
