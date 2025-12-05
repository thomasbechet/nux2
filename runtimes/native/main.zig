const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

const Self = @This();

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var core: nux.Core = try .init(allocator);
    defer core.deinit();
    var context = window.Context{};
    try context.init();
}
