const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

pub fn main() !void {
    const v = nux.Vec2.zero().add(nux.Vec2.init(1));
    std.log.info("{}", .{v});
    const allocator = std.heap.page_allocator;
    var core = try nux.Core.init(allocator, .{});
    defer core.deinit();
    try core.update();
    var context = window.Context{};
    try context.run(core);
}
