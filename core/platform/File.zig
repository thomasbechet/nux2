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
        const handle = try alloc.create(std.fs.File);
        handle.* = file;
        return @ptrCast(handle);
    }
    fn close(_: *anyopaque, handle: Handle) void {
        const alloc = std.heap.page_allocator;
        const file: *std.fs.File = @ptrCast(@alignCast(handle));
        file.close();
        alloc.destroy(file);
    }
    fn stat(_: *anyopaque, handle: Handle) anyerror!FileStat {
        const file: *std.fs.File = @ptrCast(@alignCast(handle));
        const fstat = try file.stat();
        return .{ .size = @intCast(fstat.size) };
    }
    fn seek(_: *anyopaque, handle: Handle, offset: u32) anyerror!void {
        const file: *std.fs.File = @ptrCast(@alignCast(handle));
        try file.seekTo(@intCast(offset));
    }
    fn read(_: *anyopaque, handle: Handle, data: []u8) anyerror!void {
        const file: *std.fs.File = @ptrCast(@alignCast(handle));
        var buf: [256]u8 = undefined;
        var reader = file.reader(&buf);
        try reader.interface.readSliceAll(data);
    }
    fn write(_: *anyopaque, handle: Handle, data: []const u8) anyerror!void {
        const file: *std.fs.File = @ptrCast(@alignCast(handle));
        _ = try file.write(data);
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
