const std = @import("std");
const nux = @import("nux");
const Logger = @import("Logger.zig");
const File = @import("File.zig");
const Window = @import("Window.zig");

var core: *nux.Core = undefined;

export fn runtime_init() void {
    core = nux.Core.init(.{
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
        .window = .{ .ptr = undefined, .vtable = &.{
            .open = Window.open,
            .close = Window.close,
            .resize = Window.resize,
        } },
        .config = .{
            .mount = "cart.bin",
            .logModuleInitialization = true,
        },
    }) catch return;
}

export fn runtime_update() void {
    core.update() catch {};
}
