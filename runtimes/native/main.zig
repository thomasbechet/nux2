const std = @import("std");
const nux = @import("nux");
const api = @import("api.zig");
const Window = @import("Window.zig");

fn parseArgs(args: [][:0]u8, config: *nux.Platform.Config) !void {
    var i: usize = 1;
    while (i < args.len) {
        var arg = args[i];
        // Consume - and --
        var is_param = false;
        while (arg.len > 0 and arg[0] == '-') {
            arg = arg[1..];
            is_param = true;
        }
        if (is_param) {
            // Check param
            if (std.mem.eql(u8, arg, "p")) {
                // Read path
                i += 1;
                if (i >= args.len) {
                    return error.MissingPath;
                }
                config.mount = args[i];
            }
        } else {
            // Build command
            if (std.mem.eql(u8, arg, "build")) {
                i += 1;
                if (i >= args.len) {
                    return error.MissingBuildGlob;
                }
                config.command = .{ .build = .{ .glob = args[i] } };
            }
        }
        i += 1;
    }
}

pub fn main() !void {
    // Create allocator
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Parse arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Configure platform
    var platform = nux.Platform{
        .allocator = allocator,
    };

    // Parse arguments
    try parseArgs(args, &platform.config);

    // Init core
    var core: *nux.Core = try .init(platform);
    defer core.deinit();
    // Init window
    var window: Window = .init();
    defer window.deinit();
    try window.start();

    // Run forever
    while (core.isRunning()) {
        try window.pollEvents(core);
        try core.update();
        try window.swapBuffers();
    }
}
