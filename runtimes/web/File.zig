const nux = @import("nux");
const std = @import("std");

const Platform = nux.Platform.File;

const FileHandle = u32;
const FileStat = extern struct {
    size: u64,
};

extern fn runtime_open(path: [*c]const u8, len: u32, mode: u32, slot: [*c]u32) bool;
extern fn runtime_close(slot: u32) void;
extern fn runtime_seek(slot: u32, cursor: u64) bool;
extern fn runtime_read(slot: u32, p: [*c]const u8, n: u32) bool;
extern fn runtime_stat(path: [*c]const u8, len: u32, pstat: [*c]FileStat) bool;

pub fn open(_: *anyopaque, path: []const u8, mode: Platform.Mode) anyerror!Platform.Handle {
    var slot: u32 = undefined;
    if (!runtime_open(path.ptr, @intCast(path.len), @intFromEnum(mode), &slot)) {
        return error.BackendError;
    }
    return @ptrFromInt(slot);
}
pub fn close(_: *anyopaque, handle: Platform.Handle) void {
    runtime_close(@intFromPtr(handle));
}
pub fn seek(_: *anyopaque, handle: Platform.Handle, cursor: u64) anyerror!void {
    if (!runtime_seek(@intFromPtr(handle), cursor)) {
        return error.BackendError;
    }
}
pub fn read(_: *anyopaque, handle: Platform.Handle, buffer: []u8) anyerror!void {
    if (!runtime_read(@intFromPtr(handle), @ptrCast(buffer), @intCast(buffer.len))) {
        return error.BackendError;
    }
}
pub fn write(_: *anyopaque, _: Platform.Handle, _: []const u8) anyerror!void {}
pub fn stat(_: *anyopaque, path: []const u8) anyerror!Platform.Stat {
    var file_stat: FileStat = undefined;
    if (!runtime_stat(
        path.ptr,
        @intCast(path.len),
        @ptrCast(&file_stat),
    )) {
        return error.BackendError;
    }
    return .{
        .size = file_stat.size,
    };
}
pub fn openDir(_: *anyopaque, _: []const u8) anyerror!Platform.Handle {
    // Ignored
    return undefined;
}
pub fn closeDir(_: *anyopaque, _: Platform.Handle) void {
    // Ignored
}
pub fn next(_: *anyopaque, _: Platform.Handle, _: []u8) anyerror!?usize {
    // Ignored
    return null;
}
