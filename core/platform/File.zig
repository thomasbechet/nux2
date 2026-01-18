const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque,
vtable: *const VTable,

pub const OpenMode = enum {
    read,
    write_truncate,
    write_append,
};

pub const FileStat = struct {
    size: u32,
};

pub const Handle = *anyopaque;

pub const VTable = struct {
    open: *const fn (*anyopaque, path: []const u8, mode: OpenMode) anyerror!Handle,
    close: *const fn (*anyopaque, handle: Handle) void,
    stat: *const fn (*anyopaque, handle: Handle) anyerror!FileStat,
    seek: *const fn (*anyopaque, handle: Handle, cursor: u32) anyerror!void,
    read: *const fn (*anyopaque, handle: Handle, data: []u8) anyerror!void,
    write: *const fn (*anyopaque, handle: Handle, data: []const u8) anyerror!void,
};

const Default = struct {
    const FileHandle = struct {
        file: std.fs.File,
        reader: std.fs.File.Reader,
        buffer: [256]u8,
    };
    fn open(_: *anyopaque, path: []const u8, mode: OpenMode) anyerror!Handle {
        const alloc = std.heap.page_allocator;
        const file = out: switch (mode) {
            .read => try std.fs.cwd().openFile(path, .{ .mode = .read_only }),
            .write_truncate => try std.fs.cwd().createFile(path, .{ .truncate = true }),
            .write_append => {
                const f = try std.fs.cwd().createFile(path, .{});
                try f.seekFromEnd(0);
                break :out f;
            },
        };
        const handle = try alloc.create(FileHandle);
        handle.file = file;
        handle.reader = file.reader(&handle.buffer);
        return @ptrCast(handle);
    }
    fn close(_: *anyopaque, handle: Handle) void {
        const alloc = std.heap.page_allocator;
        const file: *FileHandle = @ptrCast(@alignCast(handle));
        file.file.close();
        alloc.destroy(file);
    }
    fn stat(_: *anyopaque, handle: Handle) anyerror!FileStat {
        const file: *FileHandle = @ptrCast(@alignCast(handle));
        const fstat = try file.file.stat();
        return .{ .size = @intCast(fstat.size) };
    }
    fn seek(_: *anyopaque, handle: Handle, offset: u32) anyerror!void {
        const file: *FileHandle = @ptrCast(@alignCast(handle));
        try file.reader.seekTo(@intCast(offset));
    }
    fn read(_: *anyopaque, handle: Handle, data: []u8) anyerror!void {
        const file: *FileHandle = @ptrCast(@alignCast(handle));
        try file.reader.interface.readSliceAll(data);
    }
    fn write(_: *anyopaque, handle: Handle, data: []const u8) anyerror!void {
        const file: *FileHandle = @ptrCast(@alignCast(handle));
        _ = try file.file.write(data);
    }
};

pub const default: @This() = .{ .ptr = undefined, .vtable = &.{
    .open = Default.open,
    .close = Default.close,
    .stat = Default.stat,
    .seek = Default.seek,
    .read = Default.read,
    .write = Default.write,
} };
