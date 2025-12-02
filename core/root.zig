const std = @import("std");

pub const ObjectID = struct { version: u8, index: u24 };
pub const transform = @import("transform.zig");

pub fn Object(comptime T: type) type {
    return struct {
        const Self = @This();

        parent: ObjectID,
        child: ObjectID,
        prev: ObjectID,
        next: ObjectID,
        object: T,

        pub fn setParent(self: *Self, parent: ObjectID) void {
            self.parent = parent;
        }
    };
}

pub fn Objects(comptime T: type) type {
    return struct {
        const Self = @This();

        data: std.ArrayListUnmanaged(T) = .{},
        allocator: std.mem.Allocator = undefined,

        pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
            self.allocator = allocator;
            // self.data = try .initCapacity(allocator, 1000);
            _ = try self.data.addOne(self.allocator);
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit(self.allocator);
        }

        pub fn get(self: *Self, id: u32) *T {
            return &self.data.items[id];
        }
    };
}
