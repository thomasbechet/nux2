const std = @import("std");
const nux = @import("../nux.zig");

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

pub const VTable = struct {
    log: *const fn (*anyopaque, level: std.log.Level, msg: [:0]const u8) void = Default.log,
};

const Default = struct {
    fn log(_: *anyopaque, level: std.log.Level, msg: [:0]const u8) void {
        _ = level;
        var buf: [256]u8 = undefined;
        var w = std.fs.File.stdout().writer(&buf);
        w.interface.print("{s}\n", .{msg}) catch {};
        w.interface.flush() catch {};
        // switch (level) {
        //     .err => std.log.err("{s}", .{msg}),
        //     .warn => std.log.warn("{s}", .{msg}),
        //     .info => std.log.info("{s}", .{msg}),
        //     .debug => std.log.debug("{s}", .{msg}),
        // }
    }
};
