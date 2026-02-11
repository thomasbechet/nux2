const std = @import("std");
const nux = @import("nux");
const api = @import("api.zig");
const Window = @import("Window.zig");

pub fn parseArgs(allocator: std.mem.Allocator) !nux.Platform.Config {
    var cfg = nux.Platform.Config{};

    var it = std.process.args();
    _ = it.next(); // skip program name

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--log")) {
            cfg.logModuleInitialization = true;
        } else if (std.mem.eql(u8, arg, "--mount")) {
            const v = it.next() orelse return error.MissingValue;
            cfg.mount = v;
        } else if (std.mem.eql(u8, arg, "run")) {
            cfg.command = .{ .run = .{} };
        } else if (std.mem.eql(u8, arg, "build")) {
            cfg.command = .{ .build = .{} };
        } else if (std.mem.eql(u8, arg, "--script")) {
            const v = it.next() orelse return error.MissingValue;
            switch (cfg.command) {
                .run => |*r| r.script = try allocator.dupe(u8, v),
                else => return error.WrongCommand,
            }
        } else if (std.mem.eql(u8, arg, "--path")) {
            const v = it.next() orelse return error.MissingValue;
            switch (cfg.command) {
                .build => |*b| b.path = try allocator.dupe(u8, v),
                else => return error.WrongCommand,
            }
        } else if (std.mem.eql(u8, arg, "--glob")) {
            const v = it.next() orelse return error.MissingValue;
            switch (cfg.command) {
                .build => |*b| b.glob = try allocator.dupe(u8, v),
                else => return error.WrongCommand,
            }
        } else {
            return error.UnknownArgument;
        }
    }

    return cfg;
}

pub fn main() !void {
    // Create allocator
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Parse arguments
    const config = try parseArgs(allocator);

    // Configure platform
    const platform = nux.Platform{
        .allocator = allocator,
        .config = config,
    };

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
