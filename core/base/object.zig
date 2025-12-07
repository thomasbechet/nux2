const std = @import("std");
const nux = @import("../core.zig");

pub const ObjectID = struct {
    pub const @"null" = @This(){ .version = 0, .index = 0 };
    pub const TypeIndex = u16;
    pub const Version = u16;
    pub const Index = u32;

    pub fn isNull(self: *const @This()) bool {
        return self.version == 0;
    }

    type_index: TypeIndex,
    version: Version,
    index: Index,
};

const ObjectInfo = struct {
    parent: ObjectID,
    prev: ObjectID,
    next: ObjectID,
    child: ObjectID,
    version: u8,
};

const ObjectType = struct {
    info: *std.ArrayList(ObjectInfo),
    ptr: *anyopaque,
    v_new: *const fn (*anyopaque) anyerror!void,
};

pub fn Objects(comptime T: type) type {
    return struct {
        const DefaultCapacity = 1000;

        allocator: std.mem.Allocator,
        type_index: ObjectID.TypeIndex,
        data: std.ArrayList(T),
        info: std.ArrayList(ObjectInfo),
        free: std.ArrayList(ObjectID),

        pub fn init(self: *@This(), core: *nux.Core) !void {

            // Create new container entry
            self.type_index = @intCast(core.object.types.items.len);
            var container = try core.object.types.addOne(core.allocator);

            container.ptr = self;
            container.info = &self.info;

            self.allocator = core.allocator;
            self.data = try .initCapacity(core.allocator, DefaultCapacity);
            self.info = try .initCapacity(core.allocator, DefaultCapacity);
            self.free = try .initCapacity(core.allocator, DefaultCapacity);
        }

        pub fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
            self.info.deinit(self.allocator);
            self.free.deinit(self.allocator);
        }

        pub fn new(self: *@This()) !ObjectID {
            if (self.free.pop()) |id| {
                return .{
                    .type_index = self.type_index,
                    .index = id.index,
                    .version = id.version + 1,
                };
            } else {
                const data = try self.data.addOne(self.allocator);
                data.* = .{};
                var meta = try self.info.addOne(self.allocator);
                meta.version = 1;
                return .{
                    .type_index = self.type_index,
                    .index = @intCast(self.data.items.len - 1),
                    .version = meta.version,
                };
            }
        }

        pub fn delete(self: *@This(), id: ObjectID) void {
            _ = self;
            _ = id;
        }

        pub fn get(self: *@This(), id: ObjectID) ?*T {
            if (self.dead.isSet(id.index)) {
                return null;
            }
            return &self.data.items[id];
        }
    };
}

allocator: std.mem.Allocator,
types: std.ArrayList(ObjectType),

pub fn init(self: *@This(), core: *nux.Core) !void {
    self.allocator = core.allocator;
    self.types = try .initCapacity(core.allocator, 32);
}
pub fn deinit(self: *@This()) void {
    self.types.deinit(self.allocator);
}

pub fn getParent(self: *@This(), id: ObjectID) ?ObjectID {
    return self.types.items[id.type_index].info.items[id.index].parent;
}
