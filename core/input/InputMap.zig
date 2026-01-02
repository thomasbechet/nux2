const std = @import("std");
const nux = @import("../core.zig");
const Input = @import("Input.zig");

const Self = @This();

allocator: std.mem.Allocator,
objects: nux.ObjectPool(struct {
    const DTO = struct {};
    const Entry = struct {
        name: []const u8,
        key: Input.Key,
    };
    entries: std.ArrayList(Entry),
    sensivity: f32,

    fn findEntry(self: *@This(), name: []const u8) *Entry {
        return for (self.entries) |*entry| {
            if (std.mem.eql(u8, name, entry.name)) break entry;
        };
    }
}),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn new(self: *Self, parent: nux.ObjectID) !nux.ObjectID {
    return try self.objects.add(parent, .{
        .entries = try .initCapacity(self.allocator, 10),
        .sensivity = 1,
    });
}
pub fn delete(_: *Self, _: nux.ObjectID) void {}
// pub fn bindKey(self: *Self, map: nux.ObjectID, name: []const u8, key: input.Key) void {}
