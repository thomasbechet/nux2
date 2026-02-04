const std = @import("std");
const nux = @import("nux");

extern fn runtime_log(level: u32, msg: [*c]const u8, len: u32) void;

fn log(_: *anyopaque, level: std.log.Level, msg: [:0]const u8) void {
    runtime_log(@intFromEnum(level), msg, msg.len);
}

export fn runtime_init() void {
    var c = nux.Core.init(.{ .allocator = std.heap.wasm_allocator, .logger = .{ .ptr = undefined, .vtable = &.{
        .log = log,
    } } }) catch unreachable;
    defer c.deinit();
    c.update() catch unreachable;
}
