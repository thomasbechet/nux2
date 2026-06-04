const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

const Type = enum(u32) {
    i32,
    f32,
    vec3,
};

const Property = struct {
    name: []const u8,
    type: Type,
};

const Kind = struct {
    name: []const u8,
};

const ID = packed struct(u32) {
    version: u8,
    index: u24,
};

allocator: std.mem.Allocator,
properties: std.ArrayList(Property),
kinds: std.ArrayList(Kind), 

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .allocator = allocator,
        .properties = .empty,
        .kinds = .empty,
    };
}
pub fn deinit(self: *Self) void {
    self.properties.deinit(self.allocator);
    self.kinds.deinit(self.allocator);
}

pub fn addProperty(self: *Self, comptime T: type) !void {

}
