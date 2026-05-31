const std = @import("std");
pub const Registry = @import("Registry.zig");
pub const Transform = @import("Transform.zig");
pub const ID = u32;

const Self = @This();

const Platform = struct {};

pub fn Objects(comptime T: type) type {
    return struct {
        pub fn register(core: *Self, comptime properties: anytype) !@This() {
            try core.registry.registerObject(T, properties);
        }
    };
}

registry: Registry,
platform: Platform,

pub fn init(allocator: std.mem.Allocator) !Self {
    var core = Self{
        .registry = .init(allocator),
        .platform = .{},
    };
    errdefer core.deinit();

    try core.registerModule(Transform);

    return core;
}
pub fn deinit(self: *Self) void {
    self.registry.deinit();
}
pub fn registerModule(self: *Self, comptime M: type) !void {

    // Add module

    // Register module
    if (@hasDecl(M, "register")) {
        try M.register(&self.registry);
    }

    // Register callbacks

}

test "core" {
    var core: Self = .init(std.testing.allocator);
    defer core.deinit();
}
