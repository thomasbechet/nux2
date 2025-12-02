const std = @import("std");

pub const ObjectID = struct { version: u8, index: u24 };

const Object = struct {
    parent: ObjectID,
    prev: ObjectID,
    next: ObjectID,
    child: ObjectID,
};

pub fn Objects(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator = undefined,
        objects: std.ArrayList(Object) = .{},
        data: std.ArrayList(T) = .{},

        pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
            self.allocator = allocator;
            self.objects = try .initCapacity(allocator, 1000);
            self.data = try .initCapacity(allocator, 1000);
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit(self.allocator);
        }

        pub fn get(self: *Self, id: u32) *T {
            return &self.data.items[id];
        }
    };
}
