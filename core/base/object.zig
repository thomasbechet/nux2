const std = @import("std");
const nux = @import("../core.zig");

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

    version: Object.Version,
    index: Object.Index,
};

const Object = struct {
    pub const Version = u8;
    pub const Index = u24;

    version: u8,
    pool_index: u24,
    type_index: ObjectType.Index,

    parent: ObjectID,
    prev: ObjectID,
    next: ObjectID,
    child: ObjectID,
};

pub const ObjectType = struct {
    const Index = u32;

    name: []const u8,
    v_ptr: *anyopaque,
    v_new: *const fn (*anyopaque, parent: ObjectID) anyerror!ObjectID,
    v_destroy: *const fn (*anyopaque, std.mem.Allocator) void,
    // v_load_json: *const fn (*anyopaque, id: ObjectID, s: []const u8) anyerror!void,
    // v_save_json: *const fn (*anyopaque, id: ObjectID, allocator: std.mem.Allocator) anyerror!std.ArrayList(u8),
};

pub fn ObjectPool(comptime T: type) type {
    return struct {
        const default_capacity = 1000;

        allocator: std.mem.Allocator,
        context: *anyopaque,
        object: *Module,
        type_index: ObjectType.Index,
        data: std.ArrayList(T),
        ids: std.ArrayList(ObjectID),

        pub fn new(self: *@This(), parent: ObjectID) !ObjectID {
            const pool_index = self.data.items.len;
            const data = try self.data.addOne(self.allocator);
            const id = try self.object.add(parent, @intCast(pool_index), self.type_index);
            (try self.ids.addOne(self.allocator)).* = id;
            if (@hasDecl(T, "init")) {
                try T.init(data, @ptrCast(@alignCast(self.context)));
            }
            return id;
        }
        pub fn delete(self: *@This(), id: ObjectID) !void {
            const obj = try self.object.get(id);
            // deinit object
            const data = &self.data.items[obj.pool_index];
            if (@hasDecl(data, "deinit")) {
                T.deinit(data, self.context);
            }
            // remove object from graph
            try self.object.removeUnchecked(id);
            // update last item before swap remove
            self.object.updatePoolIndex(self.ids.items[obj.pool_index], obj.pool_index);
            // remove from array
            self.data.swapRemove(obj.pool_index);
            self.ids.swapRemove(obj.pool_index);
        }

        pub fn get(self: *@This(), id: ObjectID) !*T {
            const obj = try self.object.get(id);
            return &self.data.items[obj.pool_index];
        }

        // pub fn load(self: *@This(), id: ObjectID, comptime data: anytype) !void {
        //     const object = try self.get(id);
        //     if (@hasDecl(T, "load")) {
        //         try T.load(object, self.context, data);
        //     } else if (comptime std.meta.eql(T, T.Data)) {
        //         object.* = data;
        //     } else {
        //         @compileError("no load function for object type " ++ @typeName(T));
        //     }
        // }

        // pub fn loadJson(self: *@This(), id: ObjectID, s: []const u8) !void {
        //     if (@hasDecl(T, "Data")) {
        //         const parsed = try std.json.parseFromSlice(T.Data, self.allocator, s, .{ .allocate = .alloc_always });
        //         defer parsed.deinit();
        //         try self.load(id, parsed.value);
        //     }
        // }

        // pub fn save(self: *@This(), id: ObjectID) !T.Data {
        //     const data = try self.get(id);
        //     if (@hasDecl(T, "save")) {
        //         return try T.save(data, self.context);
        //     } else if (comptime std.meta.eql(T, T.Data)) {
        //         return data.*;
        //     } else {
        //         @compileError("no save function for object type " ++ @typeName(T));
        //     }
        // }

        // pub fn saveJson(self: *@This(), id: ObjectID, allocator: std.mem.Allocator) !std.ArrayList(u8) {
        //     const props = try self.save(id);
        //     var out: std.io.Writer.Allocating = .init(allocator);
        //     try std.json.Stringify.value(props, .{ .emit_null_optional_fields = false, .whitespace = .indent_2 }, &out.writer);
        //     return out.toArrayList();
        // }
    };
}

pub const Module = struct {
    allocator: std.mem.Allocator,
    objects: std.ArrayList(Object),
    free: std.ArrayList(Object.Index),
    types: std.ArrayList(ObjectType),

    pub fn init(self: *Module, core: *nux.Core) !void {
        self.allocator = core.allocator;
        self.objects = try .initCapacity(core.allocator, 1024);
        self.free = try .initCapacity(core.allocator, 1024);
        self.types = try .initCapacity(core.allocator, 64);
    }
    pub fn deinit(self: *Module) void {
        self.objects.deinit(self.allocator);
        self.free.deinit(self.allocator);
        self.types.deinit(self.allocator);
    }

    fn add(self: *Module, parent: ObjectID, pool_index: Object.Index, type_index: ObjectType.Index) !ObjectID {
        var index: Object.Index = undefined;
        if (self.free.pop()) |idx| {
            index = idx;
        } else {
            index = @intCast(self.objects.items.len);
            const object = try self.objects.addOne(self.allocator);
            object.version = 0;
        }
        var object = &self.objects.items[index];
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
    fn removeUnchecked(self: *Module, id: ObjectID) !void {
        var obj = &self.objects.items[id.index];
        obj.version += 1;
        obj.pool_index(try self.free.addOne(self.allocator)).* = id.index;
    }
    fn updatePoolIndex(self: *Module, id: ObjectID, pool_index: ObjectID.Index) void {
        self.objects.items[id.index].pool_index = pool_index;
    }
    fn get(self: *Module, id: ObjectID) !*Object {
        if (id.isNull()) {
            return ObjectError.nullId;
        }
        if (id.index >= self.objects.items.len) {
            return ObjectError.invalidIndex;
        }
        const obj = &self.objects.items[id.index];
        if (obj.version != id.version) {
            return ObjectError.invalidVersion;
        }
        return obj;
    }

    pub fn register(self: *Module, comptime T: type, context: *anyopaque, comptime Options: anytype) !*ObjectPool(T) {
        _ = Options;
        std.log.info("register object {s}...", .{@typeName(T)});
        const gen = struct {
            fn new(pointer: *anyopaque, parent: ObjectID) !ObjectID {
                const objects: *ObjectPool(T) = @ptrCast(@alignCast(pointer));
                return objects.new(parent);
            }
            fn destroy(pointer: *anyopaque, alloc: std.mem.Allocator) void {
                const objects: *ObjectPool(T) = @ptrCast(@alignCast(pointer));
                objects.data.deinit(objects.allocator);
                objects.ids.deinit(objects.allocator);
                alloc.destroy(objects);
            }
        };
        const type_index: ObjectType.Index = @intCast(self.types.items.len);
        const pool = try self.allocator.create(ObjectPool(T));
        pool.* = .{
            .allocator = self.allocator,
            .context = context,
            .type_index = type_index,
            .object = self,
            .data = try .initCapacity(self.allocator, 1000),
            .ids = try .initCapacity(self.allocator, 1000),
        };
        const typ = try self.types.addOne(self.allocator);
        typ.* = .{
            .name = @typeName(T),
            .v_ptr = pool,
            .v_new = gen.new,
            .v_destroy = gen.destroy,
        };
        return pool;
    }

    pub fn new(self: *Module, name: []const u8, parent: ObjectID) !ObjectID {
        if (self.types.getPtr(name)) |typ| {
            return try typ.v_new(typ.ptr, parent);
        }
        return ObjectError.unknownType;
    }
    // pub fn loadJson(self: *@This(), id: ObjectID, s: []const u8) !void {
    //     const typ = try self.getType(id.type_index);
    //     try typ.v_load_json(typ.ptr, id, s);
    // }
    // pub fn saveJson(self: *@This(), id: ObjectID, allocator: std.mem.Allocator) !std.ArrayList(u8) {
    //     const typ = try self.getType(id.type_index);
    //     return try typ.v_save_json(typ.ptr, id, allocator);
    // }
    pub fn getParent(self: *Module, id: ObjectID) !ObjectID {
        const obj = try self.get(id);
        return obj.parent;
    }
    pub fn setParent(self: *Module, id: ObjectID, parent: ObjectID) !void {
        _ = parent;
        const obj = try self.get(id);
        _ = obj;
    }
    pub fn setName(self: *Module, id: ObjectID, name: []const u8) void {
        _ = self;
        _ = id;
        _ = name;
    }
    pub fn getType(self: *Module, id: ObjectID) !*ObjectType {
        const obj = try self.get(id);
        return &self.types.items[obj.type_index];
    }
    // pub fn findEntity(self: *Module, id: ObjectID) !ObjectID {
    //
    // }
    fn dump_recurs(self: *Module, id: ObjectID, depth: u32) void {
        const obj = self.get(id) catch return;
        const typ = self.getType(id) catch unreachable;
        for (0..depth) |_| {
            std.log.info(" ", .{});
        }
        std.debug.print("type {s}:\n", .{typ.name});

        var next = obj.child;
        while (!next.isNull()) {
            const cinfo = self.get(id) catch break;
            dump_recurs(self, next, depth + 1);
            next = cinfo.next;
        }
    }
    pub fn dump(self: *Module, id: ObjectID) void {
        dump_recurs(self, id, 0);
    }
};
