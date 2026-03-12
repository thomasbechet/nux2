const std = @import("std");

pub fn ObjectPool(T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        data: std.ArrayList(T),
        free: ?usize,
    };
}
