const std = @import("std");
const nux = @import("core.zig");

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

const Node = struct {
    parent: ObjectID,
    prev: ObjectID,
    next: ObjectID,
    child: ObjectID,
};

allocator: std.mem.Allocator,
nodes: std.ArrayList(Node),
type_table: TypeTable,

pub fn init(allocator: std.mem.Allocator) !@This() {
    return .{
        .allocator = allocator,
        .nodes = try .initCapacity(allocator, 1000),
        .type_table = .{},
    };
}
pub fn deinit(self: *@This()) void {
    self.nodes.deinit(self.allocator);
}

const TypeTable = struct {
    next_type_index: ObjectID.TypeIndex = 0,

    fn genTypeIndex(self: *@This()) ObjectID.TypeIndex {
        const next = self.next_type_index;
        self.next_type_index += 1;
        return next;
    }
};

pub fn Objects(comptime T: type) type {
    return struct {
        const ObjectMeta = struct {
            node_index: u32,
            version: u8,
        };

        const DefaultCapacity = 1000;

        allocator: std.mem.Allocator,
        type_index: ObjectID.TypeIndex,
        data: std.ArrayList(T),
        meta: std.ArrayList(ObjectMeta),
        free: std.ArrayList(ObjectID),

        pub fn init(core: *nux.Core) !@This() {
            return .{
                .allocator = core.allocator,
                .type_index = core.objects.type_table.genTypeIndex(),
                .data = try .initCapacity(core.allocator, DefaultCapacity),
                .meta = try .initCapacity(core.allocator, DefaultCapacity),
                .free = try .initCapacity(core.allocator, DefaultCapacity),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
            self.meta.deinit(self.allocator);
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
                var meta = try self.meta.addOne(self.allocator);
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

test "objects" {
    try std.testing.expect(@sizeOf(ObjectID) == @sizeOf(u64));
    const allocator = std.testing.allocator;
    const MyObject = struct {
        field_a: u32,
    };
    var core = try nux.Core.init(allocator, .{});
    defer core.deinit();
    var objects: Objects(MyObject) = try .init(core);
    defer objects.deinit();
}
