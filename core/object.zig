const std = @import("std");
const nux = @import("core.zig");

pub const ObjectError = error{
    invalidIndex,
    invalidType,
    invalidVersion,
};

pub const ObjectID = packed struct(u64) {
    pub const @"null" = @This(){ .type_index = 0, .version = 0, .index = 0 };
    pub const TypeIndex = u16;
    pub const Version = u16;
    pub const Index = u32;

    pub fn isNull(self: *const @This()) bool {
        return self.version == 0;
    }
    pub fn setNull(self: *@This()) void {
        self.version = 0;
    }

    type_index: TypeIndex,
    version: Version,
    index: Index,
};

const ObjectMeta = struct {
    version: u8,
    hash: u32,
    alive: bool,
    parent: ObjectID,
    prev: ObjectID,
    next: ObjectID,
    child: ObjectID,
};

pub const ObjectType = struct {
    objects: *std.ArrayList(ObjectMeta),
    name: []const u8,
    ptr: *anyopaque,
    v_new: *const fn (*anyopaque, id: ObjectID) anyerror!ObjectID,
    v_load_json: *const fn (*anyopaque, id: ObjectID, s: []const u8) anyerror!void,
    v_save_json: *const fn (*anyopaque, id: ObjectID, allocator: std.mem.Allocator) anyerror!std.ArrayList(u8),
};

pub fn Objects(comptime T: type) type {
    return struct {
        const default_capacity = 1000;

        allocator: std.mem.Allocator,
        context: *anyopaque,
        type_index: ObjectID.TypeIndex,
        data: std.ArrayList(T),
        objects: std.ArrayList(ObjectMeta),
        free: std.ArrayList(ObjectID.Index),

        pub fn init(
            self: *@This(),
            core: *nux.Core,
            context: *anyopaque,
        ) !void {
            self.type_index = @intCast(core.object.types.items.len);

            const Self = @This();
            const gen = struct {
                fn new(pointer: *anyopaque, id: ObjectID) anyerror!ObjectID {
                    const p: *Self = @ptrCast(@alignCast(pointer));
                    return try Self.new(p, id);
                }
                // fn loadJson(pointer: *anyopaque, id: ObjectID, s: []const u8) anyerror!void {
                //     const p: *Self = @ptrCast(@alignCast(pointer));
                //     try Self.loadJson(p, id, s);
                // }
                // fn saveJson(pointer: *anyopaque, id: ObjectID, allocator: std.mem.Allocator) anyerror!std.ArrayList(u8) {
                //     const p: *Self = @ptrCast(@alignCast(pointer));
                //     return try Self.saveJson(p, id, allocator);
                // }
            };

            var typ = try core.object.types.addOne(core.allocator);
            typ.name = @typeName(T);
            typ.ptr = self;
            typ.objects = &self.objects;
            typ.v_new = gen.new;
            // typ.v_load_json = gen.loadJson;
            // typ.v_save_json = gen.saveJson;

            self.allocator = core.allocator;
            self.context = context;
            self.data = try .initCapacity(core.allocator, default_capacity);
            self.objects = try .initCapacity(core.allocator, default_capacity);
            self.free = try .initCapacity(core.allocator, default_capacity);
        }

        pub fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
            self.objects.deinit(self.allocator);
            self.free.deinit(self.allocator);
        }

        pub fn new(self: *@This(), parent: ObjectID) !ObjectID {
            var index: ObjectID.Index = undefined;
            if (self.free.pop()) |idx| {
                index = idx;
            } else {
                index = @intCast(self.data.items.len);
                _ = try self.data.addOne(self.allocator);
                const info = try self.objects.addOne(self.allocator);
                info.version = 0;
            }
            const data = &self.data.items[index];
            var info = &self.objects.items[index];
            info.version += 1;
            info.alive = true;
            info.parent = parent;
            info.child = .null;
            info.next = .null;
            info.prev = .null;
            if (@hasDecl(T, "init")) {
                try T.init(data, self.context);
            }
            return .{
                .index = index,
                .type_index = self.type_index,
                .version = info.version,
            };
        }

        pub fn getID(self: *@This(), ptr: *T) ObjectID {
            const index = @intFromPtr(ptr) - @intFromPtr(&self.data.items[0]);
            return .{
                .type_index = self.type_index,
                .index = @intCast(index),
                .version = self.objects.items[index].version,
            };
        }

        pub fn delete(self: *@This(), id: ObjectID) void {
            if (self.get(id)) |data| {
                if (@hasDecl(data, "deinit")) {
                    T.deinit(data, self.context);
                }
            }
        }

        pub fn get(self: *@This(), id: ObjectID) !*T {
            if (self.type_index != id.type_index) {
                return ObjectError.invalidType;
            }
            if (id.index >= self.objects.items.len or !self.objects.items[id.index].alive) {
                return ObjectError.invalidIndex;
            }
            if (self.objects.items[id.index].version != id.version) {
                return ObjectError.invalidVersion;
            }
            return &self.data.items[id.index];
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

allocator: std.mem.Allocator,
types: std.StringHashMap(ObjectType),

pub fn init(self: *@This(), core: *nux.Core) !void {
    self.allocator = core.allocator;
    self.types = try .initCapacity(core.allocator, 32);
}
pub fn deinit(self: *@This()) void {
    self.types.deinit(self.allocator);
}

fn getType(self: *@This(), index: ObjectID.Index) !*ObjectType {
    if (index >= self.types.items.len) {
        return ObjectError.invalidType;
    }
    return &self.types.items[index];
}
fn get(self: *@This(), id: ObjectID) ?*anyopaque {
    if (id.version == 0) {
        return ObjectError.invalidType;
    }
    const typ = try self.getType(id.type_index);
    if (id.index >= typ.objects.items.len) {
        return ObjectError.invalidIndex;
    }
    const info = &typ.info.items[id.index];
    if (id.version != info.version) {
        return ObjectError.invalidVersion;
    }
}
fn getInfo(self: *@This(), id: ObjectID) !*ObjectMeta {
    if (id.version == 0) {
        return ObjectError.invalidType;
    }
    const typ = try self.getType(id.type_index);
    if (id.index >= typ.objects.items.len) {
        return ObjectError.invalidIndex;
    }
    const info = &typ.objects.items[id.index];
    if (id.version != info.version) {
        return ObjectError.invalidVersion;
    }
    return info;
}

pub fn new(self: *@This(), index: ObjectID.Index, parent: ObjectID) !ObjectID {
    const typ = try self.getType(index);
    return try typ.v_new(typ.ptr, parent);
}
pub fn loadJson(self: *@This(), id: ObjectID, s: []const u8) !void {
    const typ = try self.getType(id.type_index);
    try typ.v_load_json(typ.ptr, id, s);
}
pub fn saveJson(self: *@This(), id: ObjectID, allocator: std.mem.Allocator) !std.ArrayList(u8) {
    const typ = try self.getType(id.type_index);
    return try typ.v_save_json(typ.ptr, id, allocator);
}
pub fn getParent(self: *@This(), id: ObjectID) !ObjectID {
    const info = try self.getInfo(id);
    return info.parent;
}
pub fn setParent(self: *@This(), id: ObjectID, parent: ObjectID) !void {
    _ = parent;
    const info = try self.getInfo(id);
    return info.parent;
}
pub fn setName(self: *@This(), id: ObjectID, name: []const u8) void {
    _ = self;
    _ = id;
    _ = name;
}
// pub fn findEntity(self: *@This(), id: ObjectID) !ObjectID {
//
// }
fn dump_recurs(self: *@This(), id: ObjectID, depth: u32) void {
    const info = self.getInfo(id) catch return;
    const typ = self.getType(id.type_index) catch unreachable;
    for (0..depth) |_| {
        std.log.info(" ", .{});
    }
    std.debug.print("type {s}:\n", .{typ.name});

    var next = info.child;
    while (!next.isNull()) {
        const cinfo = self.getInfo(id) catch break;
        dump_recurs(self, next, depth + 1);
        next = cinfo.next;
    }
}
pub fn dump(self: *@This(), id: ObjectID) void {
    dump_recurs(self, id, 0);
}
