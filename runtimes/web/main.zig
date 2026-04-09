const std = @import("std");
const nux = @import("nux");
const Logger = @import("Logger.zig");
const File = @import("File.zig");

export fn main() void {
    var c = nux.Core.init(.{
        .allocator = std.heap.wasm_allocator,
        .logger = .{
            .ptr = undefined,
            .vtable = &.{
                .log = Logger.log,
            },
        },
        .file = .{
            .ptr = undefined,
            .vtable = &.{
                .open = File.open,
                .close = File.close,
                .seek = File.seek,
                .read = File.read,
                .write = File.write,
                .stat = File.stat,
                .open_dir = File.openDir,
                .close_dir = File.closeDir,
                .next = File.next,
            },
        },
    }) catch unreachable;
    defer c.deinit();
    c.update() catch unreachable;
}
