const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    var core: *nux.Core = try .init(.{ .allocator = gpa.allocator() }, .{}, .{});
    defer core.deinit();
    try core.update();
    var context: window.Context = .init(core);
    try context.run();
}
