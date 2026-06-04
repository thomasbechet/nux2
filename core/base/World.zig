const std = @import("std");
const nux = @import("../nux");
const Registry = @import("Registry.zig");

const Self = @This();

allocator: std.mem.Allocator,
kinds: std.ArrayList(u32),

fn Property(comptime T: type, comptime name: []const u8) type {
    return struct {};
}

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

const MyModule = struct {
    entity: Module(nux.Entity),
    positions: Property(nux.Vec3, "position"),

    pub fn mySystem(self: *Self) !void {}
};

test "world" {
    var registry: Registry = .init(std.testing.allocator);
    defer registry.deinit();
}
