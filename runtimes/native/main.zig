const std = @import("std");
const core = @import("core");
const window = @import("window.zig");
const api = @import("api.zig");

pub fn main() !void {
    var c: *core.Core = try .init(.{ .allocator = std.heap.page_allocator }, .{});
    defer c.deinit();
    try c.update();
    var context = window.Context{};
    try context.run(c);
}
