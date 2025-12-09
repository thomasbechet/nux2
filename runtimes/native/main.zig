const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

const Module = struct {
    const Self = @This();
    transform: *nux.transform,
    pub fn init(self: *Self, core: *nux.Core) !void {
        self.transform = try core.findModule(nux.transform);
        _ = try self.transform.new();
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var core = try nux.Core.init(allocator, .{Module});
    defer core.deinit();
    try core.update();
    var context = window.Context{};
    try context.run(core);
}
