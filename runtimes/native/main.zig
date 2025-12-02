const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

const Self = @This();

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    try nux.init(allocator);
    nux.deinit();
    var context = window.Context{};
    try context.init();
}
