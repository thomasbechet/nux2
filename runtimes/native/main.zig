const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var core = try nux.Core.init(allocator, .{});
    defer core.deinit();
    try core.update();
    var context = window.Context{};
    try context.run(core);
}
