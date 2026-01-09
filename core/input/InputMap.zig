const std = @import("std");
const nux = @import("../nux.zig");
const Input = nux.Input;

const Self = @This();

allocator: std.mem.Allocator,
objects: nux.ObjectPool(struct {
    const Entry = struct {
        key: Input.Key,
    };
    entries: std.StringHashMap(Entry),
    sensivity: f32,
}),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn new(self: *Self, parent: nux.ObjectID) !nux.ObjectID {
    return try self.objects.add(parent, .{
        .entries = .init(self.allocator),
        .sensivity = 1,
    });
}
pub fn delete(self: *Self, id: nux.ObjectID) !void {
    const map = try self.objects.get(id);
    map.entries.deinit();
}
pub fn bindKey(self: *Self, id: nux.ObjectID, name: []const u8, key: Input.Key) !void {
    const map = try self.objects.get(id);
    const entry = try map.entries.getOrPut(name);
    entry.value_ptr.key = key;
}
