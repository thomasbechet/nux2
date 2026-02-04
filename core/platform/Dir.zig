const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

pub const Entry = struct { name: []const u8, kind: enum {
    file,
    dir,
} };

pub const Handle = *anyopaque;

pub const VTable = struct {
    open: *const fn (*anyopaque, path: []const u8) anyerror!Handle = Default.open,
    close: *const fn (*anyopaque, handle: Handle) void = Default.close,
    next: *const fn (*anyopaque, handle: Handle) anyerror!?Entry = Default.next,
};

const Default = struct {
    const DirHandle = struct {
        dir: std.fs.Dir,
        it: std.fs.Dir.Iterator,
    };
    fn open(_: *anyopaque, path: []const u8) anyerror!Handle {
        const alloc = std.heap.page_allocator;
        const handle = try alloc.create(DirHandle);
        handle.dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
        handle.it = handle.dir.iterate();
        errdefer handle.dir.close();
        return @ptrCast(handle);
    }
    fn close(_: *anyopaque, handle: Handle) void {
        const alloc = std.heap.page_allocator;
        const dir: *DirHandle = @ptrCast(@alignCast(handle));
        dir.dir.close();
        alloc.destroy(dir);
    }
    fn next(_: *anyopaque, handle: Handle) anyerror!?Entry {
        const dir: *DirHandle = @ptrCast(@alignCast(handle));
        while (try dir.it.next()) |entry| {
            switch (entry.kind) {
                .directory => {
                    return .{
                        .name = entry.name,
                        .kind = .dir,
                    };
                },
                .file => {
                    return .{
                        .name = entry.name,
                        .kind = .file,
                    };
                },
                else => {},
            }
        }
        return null;
    }
};
