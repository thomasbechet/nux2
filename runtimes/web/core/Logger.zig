const nux = @import("nux");
const std = @import("std");

extern fn logger_log(level: u32, msg: [*c]const u8, len: u32) void;

pub fn log(_: *anyopaque, level: std.log.Level, msg: [:0]const u8) void {
    logger_log(@intFromEnum(level), msg, msg.len);
}
