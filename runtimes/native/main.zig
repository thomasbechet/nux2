const std = @import("std");
const nux = @import("nux");
const Window = @import("Window.zig");
const GPU = @import("GPU.zig");

pub fn parseArgs(args: std.process.ArgIterator) !nux.Platform.Config {
    var cfg = nux.Platform.Config{};

    var it = args;
    _ = it.next(); // skip program name

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--log")) {
            cfg.logModuleInitialization = true;
        } else if (std.mem.eql(u8, arg, "--build")) {
            cfg.build = true;
        } else if (std.mem.eql(u8, arg, "--output")) {
            const v = it.next() orelse return error.MissingValue;
            cfg.outpout = v;
        } else if (std.mem.eql(u8, arg, "--glob")) {
            const v = it.next() orelse return error.MissingValue;
            cfg.glob = v;
        } else {
            cfg.mount = arg;
        }
    }

    return cfg;
}

pub fn main() !void {

    // Create allocator
    var gpa: std.heap.DebugAllocator(.{
        .stack_trace_frames = 10,
    }) = .init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Init window
    var window: Window = .init();
    defer window.deinit();

    // Init GPU
    var gpu: GPU = .init(allocator);

    // Parse arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    const config = try parseArgs(args);

    // Configure platform
    const platform = nux.Platform{
        .allocator = allocator,
        .config = config,
        .window = window.platform(),
        .gpu = gpu.platform(),
    };

    // Init core
    var core: *nux.Core = try .init(platform);
    defer core.deinit();

    // Run forever
    while (core.isRunning()) {
        try window.pollEvents(core);
        try core.update();
        try window.swapBuffers();
    }
}
