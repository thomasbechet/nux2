const nux = @import("nux");
const std = @import("std");

const Platform = nux.Platform.File;

fn open(_: *anyopaque, _: []const u8, _: Platform.Mode) anyerror!Platform.Handle {}
fn close(_: *anyopaque, _: Platform.Handle) void {}
fn seek(_: *anyopaque, _: Platform.Handle, _: u64) anyerror!void {}
fn read(_: *anyopaque, _: Platform.Handle, _: []u8) anyerror!void {}
fn write(_: *anyopaque, _: Platform.Handle, _: []const u8) anyerror!void {}
fn stat(_: *anyopaque, _: []const u8) anyerror!Platform.Stat {}
fn openDir(_: *anyopaque, _: []const u8) anyerror!Platform.Handle {}
fn closeDir(_: *anyopaque, _: Platform.Handle) void {
    return error.NotImplemented;
}
fn next(_: *anyopaque, _: Platform.Handle, _: []u8) anyerror!?usize {
    return error.NotImplemented;
}
