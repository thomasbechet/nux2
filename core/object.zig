const std = @import("std");

pub const ObjectID = struct { version: u8, index: u24 };

const Node = struct {
    parent: ObjectID,
    prev: ObjectID,
    next: ObjectID,
    child: ObjectID,
};

allocator: std.mem.Allocator,
nodes: std.ArrayList(Node),

pub fn init(allocator: std.mem.Allocator) !@This() {
    return .{
        .allocator = allocator,
        .nodes = try .initCapacity(allocator, 1000),
    };
}

pub fn Objects(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        data: std.ArrayList(T),

        pub fn init(allocator: std.mem.Allocator) !@This() {
            return .{
                .allocator = allocator,
                .objects = try .initCapacity(allocator, 1000),
                .data = try .initCapacity(allocator, 1000),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
        }

        pub fn get(self: *@This(), id: u32) *T {
            return &self.data.items[id];
        }
    };
}
