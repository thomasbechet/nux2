const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

pub const Mode = enum {
    read,
    write_truncate,
    write_append,
};

pub const Stat = struct {
    size: u64,
};

pub const Handle = *anyopaque;

pub const VTable = struct {
    open: *const fn (*anyopaque, path: []const u8, mode: Mode) anyerror!Handle = Default.open,
    close: *const fn (*anyopaque, handle: Handle) void = Default.close,
    seek: *const fn (*anyopaque, handle: Handle, cursor: u64) anyerror!void = Default.seek,
    read: *const fn (*anyopaque, handle: Handle, data: []u8) anyerror!void = Default.read,
    write: *const fn (*anyopaque, handle: Handle, data: []const u8) anyerror!void = Default.write,
    stat: *const fn (*anyopaque, path: []const u8) anyerror!Stat = Default.stat,
    openDir: *const fn (*anyopaque, path: []const u8) anyerror!Handle = Default.openDir,
    closeDir: *const fn (*anyopaque, handle: Handle) void = Default.closeDir,
    next: *const fn (*anyopaque, handle: Handle, name: []u8) anyerror!?usize = Default.next,
};

const Default = struct {
    const FileHandle = struct {
        file: std.fs.File,
    };
    const DirHandle = struct {
        dir: std.fs.Dir,
        walker: std.fs.Dir.Walker,
    };
    fn open(_: *anyopaque, path: []const u8, mode: Mode) anyerror!Handle {
        const file = out: switch (mode) {
            .read => try std.fs.cwd().openFile(path, .{ .mode = .read_only }),
            .write_truncate => try std.fs.cwd().createFile(path, .{ .truncate = true }),
            .write_append => {
                const f = try std.fs.cwd().createFile(path, .{});
                try f.seekFromEnd(0);
                break :out f;
            },
        };
        const handle = try std.heap.page_allocator.create(FileHandle);
        handle.file = file;
        return @ptrCast(handle);
    }
    fn close(_: *anyopaque, handle: Handle) void {
        const file: *FileHandle = @ptrCast(@alignCast(handle));
        file.file.close();
        std.heap.page_allocator.destroy(file);
    }
    fn seek(_: *anyopaque, handle: Handle, offset: u64) anyerror!void {
        const file: *FileHandle = @ptrCast(@alignCast(handle));
        try file.file.seekTo(@intCast(offset));
    }
    fn read(_: *anyopaque, handle: Handle, data: []u8) anyerror!void {
        const file: *FileHandle = @ptrCast(@alignCast(handle));
        _ = try file.file.read(data);
    }
    fn write(_: *anyopaque, handle: Handle, data: []const u8) anyerror!void {
        const file: *FileHandle = @ptrCast(@alignCast(handle));
        _ = try file.file.write(data);
    }
    fn stat(_: *anyopaque, path: []const u8) anyerror!Stat {
        const s = try std.fs.cwd().statFile(path);
        return .{
            .size = s.size,
        };
    }
    fn openDir(_: *anyopaque, path: []const u8) anyerror!Handle {
        const cwd = std.fs.cwd();
        var dir = try cwd.openDir(path, .{ .iterate = true });
        errdefer dir.close();
        const walker = try dir.walk(std.heap.page_allocator);
        const handle = try std.heap.page_allocator.create(DirHandle);
        handle.dir = dir;
        handle.walker = walker;
        return @ptrCast(handle);
    }
    fn closeDir(_: *anyopaque, handle: Handle) void {
        const dir: *DirHandle = @ptrCast(@alignCast(handle));
        dir.walker.deinit();
        dir.dir.close();
        std.heap.page_allocator.destroy(dir);
    }
    fn next(_: *anyopaque, handle: Handle, path: []u8) anyerror!?usize {
        const dir: *DirHandle = @ptrCast(@alignCast(handle));
        while (try dir.walker.next()) |entry| {
            if (entry.kind == .file) {
                const len = @min(entry.path.len, path.len);
                @memcpy(path[0..len], entry.path[0..len]);
                return len;
            }
        }
        return null;
    }
};
