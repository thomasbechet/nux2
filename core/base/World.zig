const std = @import("std");
const nux = @import("../nux");
const Registry = @import("Registry.zig");

const Self = @This();

allocator: std.mem.Allocator,
kinds: std.ArrayList(u32),

fn PropertyView(comptime T: type, comptime name: []const u8) type {
    return struct {};
}

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

const MyModule = struct {
    entity: Module(nux.Entity),
    positions: PropertyView(nux.Vec3, "position"),

    pub fn mySystem(self: *Self) !void {
        for (entity.filter()
    }
};

test "world" {
    var registry: Registry = .init(std.testing.allocator);
    defer registry.deinit();
}
