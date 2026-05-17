const std = @import("std");
const nux = @import("nux");
const System = @import("System.zig");
const Window = @import("Window.zig");
const GPU = @import("GPU.zig");

fn match(s: []const u8, option: []const u8, single: ?[]const u8) bool {
    return std.mem.eql(u8, s, option) or (single != null and
        std.mem.eql(u8, s, single.?));
}

pub fn parseArgs(args: std.process.ArgIterator) !nux.Platform.Config {
    var config = nux.Platform.Config{};

    var it = args;
    _ = it.next(); // skip program name

    while (it.next()) |arg| {
        if (match(arg, "--log", "-l")) {
            config.logModules = true;
        } else if (match(arg, "--build", "-b")) {
            config.build = true;
        } else if (match(arg, "--output", "-o")) {
            const v = it.next() orelse return error.MissingValue;
            config.outpout = v;
        } else if (match(arg, "--glob", "-g")) {
            const v = it.next() orelse return error.MissingValue;
            config.glob = v;
        } else if (match(arg, "--headless", null)) {
            config.headless = true;
        } else {
            config.mount = arg;
        }
    }

    return config;
}

pub fn main() !void {

    // Create allocator
    var system: System = .init();
    defer system.deinit();
    const allocator = system.gpa.allocator();

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
        .config = config,
        .allocator = allocator,
        .system = system.platform(),
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
