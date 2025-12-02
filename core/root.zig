const std = @import("std");
pub const Objects = @import("object.zig").Objects;

pub var transform = @import("transform.zig"){};
pub var object = @import("object.zig"){};

pub fn init(allocator: std.mem.Allocator) !void {
    try transform.init(allocator);
}
pub fn deinit() void {}
