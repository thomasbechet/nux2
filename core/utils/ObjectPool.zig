const std = @import("std");

pub fn ObjectPool(T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        free: ?usize = null,
        data: std.ArrayList(union {
            used: T,
            free: ?usize,
        }) = .empty,

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{
                .allocator = allocator,
            };
        }
        pub fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
        }
        pub fn add(self: *@This(), data: T) !usize {
            if (self.free) |free| {
                self.free = self.data.items[free].free;
                self.data.items[free].used = data;
                return free;
            } else {
                const index: usize = @intCast(self.data.items.len);
                try self.data.append(self.allocator, .{ .used = data });
                return index;
            }
        }
        pub fn remove(self: *@This(), index: usize) void {
            self.data.items[index] = .{ .free = self.free };
            self.free = index;
        }
        pub fn get(self: *@This(), index: usize) *T {
            return &self.data.items[index].used;
        }
    };
}
