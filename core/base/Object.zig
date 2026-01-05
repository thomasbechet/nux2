const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const ObjectError = error{
    invalidIndex,
    invalidVersion,
    nullId,
    unknownType,
};

pub const ObjectID = packed struct(u32) {
    pub const @"null" = @This(){ .version = 0, .index = 0 };

    pub fn isNull(self: *const @This()) bool {
        return self.index == 0;
    }
    pub fn setNull(self: *@This()) void {
        self.index = 0;
    }

    version: ObjectEntry.Version,
    index: ObjectEntry.Index,
};

const ObjectEntry = struct {
    pub const Version = u8;
    pub const Index = u24;
    pub const PoolIndex = u32;
    pub const TypeIndex = u32;

    version: Version,
    pool_index: PoolIndex,
    type_index: TypeIndex,

    parent: ObjectID,
    prev: ObjectID,
    next: ObjectID,
    child: ObjectID,
};

pub const ObjectType = struct {
    name: []const u8,
    v_ptr: *anyopaque,
    v_new: *const fn (*anyopaque, parent: ObjectID) anyerror!ObjectID,
    v_delete: *const fn (*anyopaque, id: ObjectID) anyerror!void,
    v_deinit: *const fn (*anyopaque) void,
};

pub fn ObjectPool(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        object: *Self,
        type_index: ObjectEntry.TypeIndex,
        data: std.ArrayList(T),
        ids: std.ArrayList(ObjectID),

        fn init(object: *Self, type_index: ObjectEntry.TypeIndex) !@This() {
            return .{
                .allocator = object.allocator,
                .type_index = type_index,
                .object = object,
                .data = try .initCapacity(object.allocator, 1000),
                .ids = try .initCapacity(object.allocator, 1000),
            };
        }
        fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
            self.ids.deinit(self.allocator);
        }

        pub fn add(self: *@This(), parent: ObjectID, data: T) !ObjectID {
            const pool_index = self.data.items.len;
            const id = try self.object.add(parent, @intCast(pool_index), self.type_index);
            (try self.data.addOne(self.allocator)).* = data;
            (try self.ids.addOne(self.allocator)).* = id;
            return id;
        }
        pub fn remove(self: *@This(), id: ObjectID) !void {
            const obj = try self.object.getEntry(id);
            // remove object from graph
            try self.object.removeUnchecked(id);
            // update last item before swap remove
            self.object.updatePoolIndex(self.ids.items[obj.pool_index], obj.pool_index);
            // remove from array
            _ = self.data.swapRemove(obj.pool_index);
            _ = self.ids.swapRemove(obj.pool_index);
        }

        pub fn get(self: *@This(), id: ObjectID) !*T {
            const obj = try self.object.getEntry(id);
            return &self.data.items[obj.pool_index];
        }
    };
}

allocator: std.mem.Allocator,
entries: std.ArrayList(ObjectEntry),
free: std.ArrayList(ObjectEntry.Index),
types: std.ArrayList(ObjectType),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.entries = try .initCapacity(self.allocator, 1024);
    self.free = try .initCapacity(self.allocator, 1024);
    self.types = try .initCapacity(self.allocator, 64);
    // reserve index 0 for null object id
    _ = try self.entries.addOne(self.allocator);
}
pub fn deinit(self: *Self) void {
    self.entries.deinit(self.allocator);
    self.free.deinit(self.allocator);
    self.types.deinit(self.allocator);
}

pub fn initModuleObjects(self: *Self, comptime T: type, module: *T) !void {
    if (@hasField(T, "objects")) {
        const type_index: ObjectEntry.TypeIndex = @intCast(self.types.items.len);
        module.objects = try .init(self, type_index);

        inline for (.{ "new", "delete" }) |func| {
            if (!@hasDecl(T, func)) {
                @compileError("module " ++ @typeName(T) ++ " has objects but is missing function " ++ func);
            }
        }

        const gen = struct {
            fn new(pointer: *anyopaque, parent: ObjectID) !ObjectID {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return mod.new(parent);
            }
            fn delete(pointer: *anyopaque, id: ObjectID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return mod.delete(id);
            }
            fn deinit(pointer: *anyopaque) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                mod.objects.deinit();
            }
        };
        (try self.types.addOne(self.allocator)).* = .{
            .name = @typeName(T),
            .v_ptr = module,
            .v_new = gen.new,
            .v_delete = gen.delete,
            .v_deinit = gen.deinit,
        };
    }
}

fn add(self: *Self, parent: ObjectID, pool_index: ObjectEntry.Index, type_index: ObjectEntry.TypeIndex) !ObjectID {
    var index: ObjectEntry.Index = undefined;
    if (self.free.pop()) |idx| {
        index = idx;
    } else {
        index = @intCast(self.entries.items.len);
        const object = try self.entries.addOne(self.allocator);
        object.version = 0;
    }
    var object = &self.entries.items[index];
    object.pool_index = pool_index;
    object.type_index = type_index;
    object.parent = parent;
    object.child = .null;
    object.next = .null;
    object.prev = .null;
    return .{
        .index = index,
        .version = object.version,
    };
}
fn removeUnchecked(self: *Self, id: ObjectID) !void {
    var obj = &self.entries.items[id.index];
    obj.version += 1;
    (try self.free.addOne(self.allocator)).* = id.index;
}
fn updatePoolIndex(self: *Self, id: ObjectID, pool_index: ObjectEntry.PoolIndex) void {
    self.entries.items[id.index].pool_index = pool_index;
}
fn getEntry(self: *Self, id: ObjectID) !*ObjectEntry {
    if (id.isNull()) {
        return ObjectError.nullId;
    }
    if (id.index >= self.entries.items.len) {
        return ObjectError.invalidIndex;
    }
    const obj = &self.entries.items[id.index];
    if (obj.version != id.version) {
        return ObjectError.invalidVersion;
    }
    return obj;
}

pub fn new(self: *Self, name: []const u8, parent: ObjectID) !ObjectID {
    const typ = try self.findType(name);
    return typ.v_new(typ.v_ptr, parent);
}
pub fn delete(self: *Self, id: ObjectID) !void {
    const typ = try self.getType(id);
    return typ.v_delete(typ.v_ptr, id);
}
pub fn getParent(self: *Self, id: ObjectID) !ObjectID {
    const obj = try self.getEntry(id);
    return obj.parent;
}
pub fn setParent(self: *Self, id: ObjectID, parent: ObjectID) !void {
    _ = parent;
    const obj = try self.getEntry(id);
    _ = obj;
}
pub fn getType(self: *Self, id: ObjectID) !*ObjectType {
    const obj = try self.getEntry(id);
    return &self.types.items[obj.type_index];
}
pub fn findType(self: *Self, name: []const u8) !*ObjectType {
    for (self.types.items) |*typ| {
        if (std.mem.eql(u8, name, typ.name)) {
            return typ;
        }
    }
    return ObjectError.unknownType;
}
fn dumpRecursive(self: *Self, id: ObjectID, depth: u32) void {
    const obj = self.getEntry(id) catch return;
    const typ = self.getType(id) catch unreachable;
    for (0..depth) |_| {
        std.log.info(" ", .{});
    }
    std.debug.print("type {s}:\n", .{typ.name});

    var next = obj.child;
    while (!next.isNull()) {
        const cinfo = self.getEntry(id) catch break;
        dumpRecursive(self, next, depth + 1);
        next = cinfo.next;
    }
}
pub fn dump(self: *Self, id: ObjectID) void {
    dumpRecursive(self, id, 0);
}
