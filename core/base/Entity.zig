const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

pub const ID = u32;
pub const KindID = u32;
pub const PropertyID = u32;

const Type = enum(u32) {
    u32,
    f32,
    string,
};
const Property = struct {
    name: []const u8,
    type: Type,
    init: *const fn (id: ID) anyerror!void,
    deinit: *const fn (id: ID) void,
};
const Kind = struct {
    properties: std.ArrayList(PropertyID),
};

allocator: std.mem.Allocator,
properties: std.ArrayList(Property),
kinds: std.ArrayList(Kind),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn deinit(self: *Self) void {}

pub fn create(kind: KindID) !ID {}
pub fn delete(id: ID) void {}
pub fn registerProperty(name: []const u8, type: Type) !PropertyID {}
pub fn registerKind(name: []const u8, properties: [][]const u8) !KindID {}
pub fn findProperty(name: []const u8) ?PropertyID {}
pub fn findKind(name: []const u8) ?KindID {}
