const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

pub const WindowResized = struct {
    width: u32,
    height: u32,
};

pub const VTable = struct {
    open: *const fn (*anyopaque, w: u32, h: u32) anyerror!void = Default.open,
    close: *const fn (*anyopaque) void = Default.close,
    resize: *const fn (*anyopaque, w: u32, h: u32) anyerror!void = Default.resize,
};

const Default = struct {
    const WindowHandle = struct {};
    fn open(_: *anyopaque, _: u32, _: u32) anyerror!void {}
    fn close(_: *anyopaque) void {}
    fn resize(_: *anyopaque, _: u32, _: u32) anyerror!void {}
};
