const std = @import("std");

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    log: *const fn (*anyopaque, level: std.log.Level, msg: []const u8) void,
};

const Default = struct {
    fn log(_: *anyopaque, level: std.log.Level, msg: []const u8) void {
        switch (level) {
            .err => std.log.err("{s}", .{msg}),
            .warn => std.log.warn("{s}", .{msg}),
            .info => std.log.info("{s}", .{msg}),
            .debug => std.log.debug("{s}", .{msg}),
        }
    }
};

pub const default: @This() = .{ .ptr = undefined, .vtable = &.{
    .log = Default.log,
} };
