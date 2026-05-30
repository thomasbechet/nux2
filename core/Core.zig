const std = @import("std");
const Database = @import("Database.zig");
const Transform = @import("Transform.zig");
const ID = u32;

const Self = @This();

pub fn Objects(comptime T: type) type {
    return struct {
        pub fn register(core: *Self, comptime properties: anytype) !@This() {
            try core.database.registerObject(T, properties);
        }
    };
}

pub fn Reg(comptime T: type) type {
    _ = T;
    return struct {
        pub fn init() @This() {
            return .{};
        }

        pub fn enumeration(self: *@This(), comptime E: type) !void {
            _ = E;
            _ = self;
        }
    };
}

database: Database,

pub fn init(allocator: std.mem.Allocator) Self {
    var core = Self{
        .database = .init(allocator),
    };
    errdefer core.deinit();
    var reg = Reg(Transform).init();
    try Transform.configure(&reg);
    return core;
}
pub fn deinit(self: *Self) void {
    self.database.deinit();
}

test "core" {
    var core: Self = .init(std.testing.allocator);
    defer core.deinit();
}
