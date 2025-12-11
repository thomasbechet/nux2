const std = @import("std");
const nux = @import("../core.zig");
const input = @import("input.zig");

const Self = @This();
const Inputmap = struct {
    const DTO = struct {};
    const Entry = struct {
        name: []const u8,
        key: input.Key,
    };
    entries: std.ArrayList(Entry),
    sensivity: f32,

    fn findEntry(self: *@This(), name: []const u8) *Entry {
        return for (self.entries) |*entry| {
            if (std.mem.eql(u8, name, entry.name)) break entry;
        };
    }

    pub fn load(_: *@This(), _: *Self, _: DTO) !void {}
    pub fn save(_: *@This(), _: *Self) !DTO {
        return .{};
    }
};

allocator: std.mem.Allocator,
inputmaps: nux.Objects(Inputmap, Inputmap.DTO, Self),

pub fn init(self: *Self, core: *nux.Core) !void {
    self.allocator = core.allocator;
    try self.inputmaps.init(core, self);
}
pub fn deinit(self: *Self) void {
    self.inputmaps.deinit();
}

pub fn new(self: *Self, parent: nux.ObjectID) !nux.ObjectID {
    var map = try self.inputmaps.new(parent);
    map.entries = try .initCapacity(self.allocator, 10);
    return self.inputmaps.getID(map);
}
// pub fn bindKey(self: *Self, map: nux.ObjectID, name: []const u8, key: input.Key) void {}
