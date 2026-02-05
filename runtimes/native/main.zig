const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

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
    if (args.len > 1) {
        platform.config.entryPoint = args[1];
    }

    // Run core
    var core: *nux.Core = try .init(platform);
    defer core.deinit();
    try core.update();
    var context: window.Context = .init(core);
    try context.run();
}
