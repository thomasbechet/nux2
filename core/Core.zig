const std = @import("std");
pub const Database = @import("Database.zig");
pub const Transform = @import("Transform.zig");
pub const ID = u32;

const Self = @This();

pub fn Objects(comptime T: type) type {
    return struct {
        pub fn register(core: *Self, comptime properties: anytype) !@This() {
            try core.database.registerObject(T, properties);
        }
    };
}

pub const Registry = struct {
    database: *Database,

    pub fn init(database: *Database) @This() {
        return .{
            .database = database,
        };
    }

    pub fn enumeration(self: *@This(), comptime M: type, comptime E: type) !void {
        _ = M;
        _ = E;
        _ = self;
    }

    pub fn function(self: *@This(), comptime M: type, comptime F: anytype) !void {
        _ = M;
        _ = F;
        _ = self;
    }

    pub fn property(self: *@This(), comptime M: type, comptime P: anytype) !void {
        _ = M;
        _ = P;
        _ = self;
    }
};

database: Database,

pub fn init(allocator: std.mem.Allocator) Self {
    var core = Self{
        .database = .init(allocator),
    };
    errdefer core.deinit();
    var reg: Registry = .init();
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
