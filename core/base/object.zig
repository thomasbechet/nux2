const std = @import("std");
const nux = @import("../core.zig");

pub const ObjectError = error{
    invalidIndex,
    invalidType,
    invalidVersion,
};

pub const ObjectID = struct {
    pub const @"null" = @This(){ .type_index = 0, .version = 0, .index = 0 };
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
    alive: bool,
};

const ObjectType = struct {
    info: *std.ArrayList(ObjectInfo),
    ptr: *anyopaque,
    v_new: *const fn (*anyopaque) anyerror!void,
};

pub fn Objects(comptime T: type, comptime DTO: type, comptime Context: type) type {
    return struct {
        const default_capacity = 1000;

        allocator: std.mem.Allocator,
        context: *Context,
        type_index: ObjectID.TypeIndex,
        data: std.ArrayList(T),
        info: std.ArrayList(ObjectInfo),
        free: std.ArrayList(ObjectID.Index),

        pub fn init(
            self: *@This(),
            core: *nux.Core,
            context: *Context,
        ) !void {
            // Create new container entry
            self.type_index = @intCast(core.object.types.items.len);
            var container = try core.object.types.addOne(core.allocator);

            container.ptr = self;
            container.info = &self.info;

            self.allocator = core.allocator;
            self.context = context;
            self.data = try .initCapacity(core.allocator, default_capacity);
            self.info = try .initCapacity(core.allocator, default_capacity);
            self.free = try .initCapacity(core.allocator, default_capacity);
        }

        pub fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
            self.info.deinit(self.allocator);
            self.free.deinit(self.allocator);
        }

        pub fn new(self: *@This(), parent: ObjectID) !*T {
            _ = parent;
            var data: *T = undefined;
            if (self.free.pop()) |index| {
                self.info.items[index].version += 1;
                data = &self.data.items[index];
            } else {
                data = try self.data.addOne(self.allocator);
                var info = try self.info.addOne(self.allocator);
                info.version = 1;
            }
            if (@hasDecl(T, "init")) {
                try T.init(data, self.context);
            }
            return data;
        }

        pub fn getID(self: *@This(), ptr: *T) ObjectID {
            const index = @intFromPtr(ptr) - @intFromPtr(&self.data.items[0]);
            return .{
                .type_index = self.type_index,
                .index = @intCast(index),
                .version = self.info.items[index].version,
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
            if (id.index >= self.info.items.len or self.info.items[id.index].alive) {
                return ObjectError.invalidIndex;
            }
            if (self.info.items[id.index].version != id.version) {
                return ObjectError.invalidVersion;
            }
            return &self.data.items[id.index];
        }

        pub fn setDTO(self: *@This(), id: ObjectID, dto: DTO) !void {
            const data = try self.get(id);
            if (@hasDecl(T, "load")) {
                try T.load(data, self.context, dto);
            } else if (comptime std.meta.eql(T, DTO)) {
                data.* = dto;
            } else {
                @compileError("no dto loading function");
            }
        }

        pub fn setJson(self: *@This(), id: ObjectID, s: []const u8) !void {
            const parsed = try std.json.parseFromSlice(DTO, self.allocator, s, .{ .allocate = .alloc_always });
            defer parsed.deinit();
            try self.setDTO(id, parsed.value);
        }

        pub fn getDTO(self: *@This(), id: ObjectID) !DTO {
            const data = try self.get(id);
            if (@hasDecl(T, "store")) {
                return try T.store(data);
            } else if (comptime std.meta.eql(T, DTO)) {
                return data.*;
            } else {
                @compileError("no dto storing function");
            }
        }

        pub fn getJson(self: *@This(), id: ObjectID, allocator: std.mem.Allocator) !std.ArrayList(u8) {
            const dto = try self.getDTO(id);
            var out: std.io.Writer.Allocating = .init(allocator);
            try std.json.Stringify.value(dto, .{ .whitespace = .indent_2 }, &out.writer);
            return out.toArrayList();
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
