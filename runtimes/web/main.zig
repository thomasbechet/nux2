const std = @import("std");
const nux = @import("nux");
const Logger = @import("Logger.zig");

export fn runtime_init() void {
    var c = nux.Core.init(.{
        .allocator = std.heap.wasm_allocator,
        .logger = .{
            .ptr = undefined,
            .vtable = &.{
                .log = Logger.log,
            },
        },
        .file = .{
            .ptr = undefined,
            .vtable = &.{},
        },
    }) catch unreachable;
    defer c.deinit();
    c.update() catch unreachable;
}
