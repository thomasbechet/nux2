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
    const platform = nux.Platform{
        .allocator = allocator,
    };
    if (args.len > 1) {
        // Is file or not
        const dir = std.fs.cwd().openDir(args[1], .{}) catch |err| {
            if (err == error.NotDir) {
                // Change to parent directory
                var parent = try std.fs.cwd().openDir(std.fs.path.dirname(args[1]), .{});
                defer parent.close();
                parent.setAsCwd();
                platform.config.cartridge = std.fs.path.basename(args[1]);
            } else {
                return err;
            }
        };
        // Set
        defer dir.close();
        try dir.setAsCwd();
    }

    // Run core
    var core: *nux.Core = try .init(platform);
    defer core.deinit();
    try core.update();
    var context: window.Context = .init(core);
    try context.run();
}
