const nux = @import("nux");

const Platform = nux.Platform.File;

const FileHandle = u32;
const FileStat = extern struct {
    size: u32,
};

extern fn file_open(path: [*c]const u8, len: u32, mode: u32, slot: [*c]u32) bool;
extern fn file_close(slot: u32) void;
extern fn file_seek(slot: u32, cursor: u32) bool;
extern fn file_read(slot: u32, p: [*c]const u8, n: u32) bool;
extern fn file_stat(path: [*c]const u8, len: u32, pstat: [*c]FileStat) bool;

pub fn open(_: *anyopaque, path: []const u8, mode: Platform.Mode) anyerror!Platform.Handle {
    var slot: u32 = undefined;
    if (!file_open(path.ptr, @intCast(path.len), @intFromEnum(mode), &slot)) {
        return error.BackendError;
    }
    return @ptrFromInt(slot);
}
pub fn close(_: *anyopaque, handle: Platform.Handle) void {
    file_close(@intFromPtr(handle));
}
pub fn seek(_: *anyopaque, handle: Platform.Handle, cursor: u32) anyerror!void {
    if (!file_seek(@intFromPtr(handle), cursor)) {
        return error.BackendError;
    }
}
pub fn read(_: *anyopaque, handle: Platform.Handle, buffer: []u8) anyerror!void {
    if (!file_read(@intFromPtr(handle), @ptrCast(buffer), @intCast(buffer.len))) {
        return error.BackendError;
    }
}
pub fn write(_: *anyopaque, _: Platform.Handle, _: []const u8) anyerror!void {}
pub fn stat(_: *anyopaque, path: []const u8) anyerror!Platform.Stat {
    var stats: FileStat = undefined;
    if (!file_stat(
        path.ptr,
        @intCast(path.len),
        @ptrCast(&stats),
    )) {
        return error.BackendError;
    }
    return .{
        .size = stats.size,
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
