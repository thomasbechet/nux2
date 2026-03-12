const std = @import("std");

/// Simple object pool structure.
/// Keep object valid when removed.
pub fn ObjectPool(T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        free: ?usize = null,
        items: std.ArrayList(struct {
            data: T,
            free: ?usize,
        }) = .empty,

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{
                .allocator = allocator,
            };
        }
        pub fn deinit(self: *@This()) void {
            self.items.deinit(self.allocator);
        }
        pub fn add(self: *@This(), data: T) !usize {
            if (self.free) |free| {
                self.free = self.items.items[free].free;
                self.items.items[free].data = data;
                return free;
            } else {
                const index: usize = @intCast(self.items.items.len);
                try self.items.append(self.allocator, .{ .data = data, .free = null });
                return index;
            }
        }
        pub fn remove(self: *@This(), index: usize) void {
            self.items.items[index].free = self.free;
            self.free = index;
        }
        pub fn get(self: *@This(), index: usize) *T {
            return &self.items.items[index].data;
        }
    };
}
