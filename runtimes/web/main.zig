const std = @import("std");
const nux = @import("nux");
const Logger = @import("Logger.zig");
const File = @import("File.zig");
const Window = @import("Window.zig");
const GPU = @import("GPU.zig");

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
        .window = .{
            .ptr = undefined,
            .vtable = &.{
                .open = Window.open,
                .close = Window.close,
                .resize = Window.resize,
            },
        },
        .gpu = .{
            .ptr = undefined,
            .vtable = &.{
                .create_device = GPU.createDevice,
                .delete_device = GPU.deleteDevice,
                .create_pipeline = GPU.createPipeline,
                .delete_pipeline = GPU.deletePipeline,
                .create_texture = GPU.createTexture,
                .delete_texture = GPU.deleteTexture,
                .update_texture = GPU.updateTexture,
                .create_buffer = GPU.createBuffer,
                .delete_buffer = GPU.deleteBuffer,
                .update_buffer = GPU.updateBuffer,
                .submit_commands = GPU.submitCommands,
            },
        },
        .config = .{
            .mount = "cart.bin",
            .logModuleInitialization = true,
        },
    }) catch return;
}

export fn runtime_update() void {
    core.update() catch {};
}
