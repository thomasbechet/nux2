const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const Version = u8;
pub const EntryIndex = u24;
pub const PoolIndex = u32;
pub const TypeIndex = u32;

pub const PropertyValue = union(enum) {
    id: nux.ID,
    vec2: nux.Vec2,
    vec3: nux.Vec3,
    vec4: nux.Vec4,
    quat: nux.Quat,
};

const EmptyNode = struct {
    dummy: u32 = 0,
};

pub const ID = packed struct(u32) {
    pub const @"null" = @This(){ .version = 0, .index = 0 };

    pub fn isNull(self: *const @This()) bool {
        return self.index == 0;
    }
    pub fn setNull(self: *@This()) void {
        self.index = 0;
    }
    pub fn value(self: @This()) u32 {
        return @bitCast(self);
    }

    version: Version,
    index: EntryIndex,
};

const NodeEntry = struct {
    version: Version = 1,
    pool_index: PoolIndex = 0,
    type_index: TypeIndex = 0,
    parent: EntryIndex = 0,
    prev: EntryIndex = 0,
    next: EntryIndex = 0,
    first_child: EntryIndex = 0,
    last_child: EntryIndex = 0,
    name: [64]u8 = undefined,
    name_len: usize = 0,

    fn getName(self: *@This()) []const u8 {
        return self.name[0..self.name_len];
    }
    fn setName(self: *@This(), name: []const u8) void {
        std.mem.copyForwards(u8, &self.name, name);
        self.name_len = name.len;
    }
};

pub const Writer = struct {
    writer: *std.Io.Writer,
    node: *Self,
    nodes: []const ID,

    pub fn write(self: *@This(), v: anytype) !void {
        const T = @TypeOf(v);
        switch (T) {
            nux.ID => {
                if (self.node.valid(v)) {
                    try self.node.writePath(v, self.writer);
                    var found = false;
                    for (self.nodes, 0..) |id, index| {
                        if (v == id) {
                            try self.writer.writeByte(1); // Local path
                            try self.writer.writeInt(u32, @intCast(index), .little);
                            found = true;
                        }
                    }
                    if (!found) { // write full path
                        try self.writer.writeByte(2); // Global path
                        try self.node.writePath(v, self.writer);
                    }
                } else {
                    try self.writer.writeByte(0); // null
                }
            },
            nux.Vec2, nux.Vec3, nux.Vec4 => {
                try self.write(v.data);
            },
            nux.Quat => {
                try self.write(v.w);
                try self.write(v.x);
                try self.write(v.y);
                try self.write(v.z);
            },
            else => switch (@typeInfo(T)) {
                .null => {
                    try self.writer.writeByte(0);
                },
                .int, .comptime_int => {
                    try self.writer.writeLeb128(v);
                },
                .float, .comptime_float => {
                    try self.writer.writeLeb128(@as(u32, @bitCast(v)));
                },
                .bool => {
                    try self.writer.writeByte(@bitCast(v));
                },
                .optional => {
                    if (v) |data| {
                        try self.writer.writeByte(1);
                        try self.write(data);
                    } else {
                        try self.writer.writeByte(0);
                    }
                },
                .@"struct" => |S| {
                    inline for (S.fields) |F| {
                        if (F.type == void) continue;
                        if (@typeInfo(F.type) == .optional) {
                            if (@field(v, F.name) == null) {}
                        }
                        try self.write(@field(v, F.name));
                    }
                },
                .pointer => |info| switch (info.size) {
                    .one => {
                        return self.write(v.*);
                    },
                    .slice => {
                        try self.write(@as(u32, @intCast(v.len)));
                        if (info.child == u8) {
                            _ = try self.writer.write(v);
                        } else {
                            for (v) |x| {
                                try self.write(x);
                            }
                        }
                    },
                    else => @compileError("Unable to serialize type '" ++ @typeName(T) ++ "'"),
                },
                .array => {
                    for (v) |x| {
                        try self.write(x);
                    }
                },
                .vector => |info| {
                    // Write as an array.
                    const array: [info.len]info.child = v;
                    try self.write(array);
                },
                else => @compileError("Unable to serialize type '" ++ @typeName(T) ++ "'"),
            },
        }
    }
};
pub const Reader = struct {
    reader: *std.Io.Reader,
    node: *Self,
    nodes: []const ID,

    pub fn takeBytes(self: *@This()) ![]const u8 {
        const size = try self.read(u32);
        return try self.reader.take(size);
    }
    pub fn takeOptionalBytes(self: *@This()) !?[]const u8 {
        if ((try self.reader.takeByte()) == 0) {
            return null;
        }
        return try self.takeBytes();
    }
    pub fn read(self: *@This(), comptime T: type) !T {
        switch (T) {
            nux.ID => {
                const path_type = try self.reader.takeByte();
                switch (path_type) {
                    0 => {
                        return .null;
                    },
                    1 => {
                        const local_index = try self.reader.takeInt(u32, .little);
                        if (local_index > self.nodes.len) {
                            return error.invalidLocalNodeIndex;
                        }
                        return self.nodes[local_index];
                    },
                    2 => {
                        const global_path = try self.takeBytes();
                        return try self.node.findGlobal(global_path);
                    },
                    else => {
                        return error.invalidPathType;
                    },
                }
            },
            nux.Vec2, nux.Vec3, nux.Vec4 => {
                return .init(try self.read(@FieldType(T, "data")));
            },
            nux.Quat => {
                return .init(
                    try self.read(f32),
                    try self.read(f32),
                    try self.read(f32),
                    try self.read(f32),
                );
            },
            else => switch (@typeInfo(T)) {
                .int, .comptime_int => {
                    return try self.reader.takeLeb128(T);
                },
                .float, .comptime_float => {
                    return @as(T, @bitCast(try self.reader.takeLeb128(u32)));
                },
                .bool => {
                    return try self.reader.takeByte() != 0;
                },
                .optional => |info| {
                    if (try self.reader.takeByte() != 0) {
                        return try self.read(info.child);
                    } else {
                        return null;
                    }
                },
                .@"struct" => |S| {
                    var s: T = undefined;
                    inline for (S.fields) |F| {
                        if (F.type == void) continue;
                        if (@typeInfo(F.type) == .optional) {
                            if ((try self.read(bool))) {} else {}
                        }
                        @field(s, F.name) = try self.read(F.type);
                    }
                    return s;
                },
                // .pointer => |info| switch (info.size) {
                //     // .one => {
                //     //     return self.write(v.*);
                //     //     const slice = try allocator.alloc(info.child, size);
                //     // },
                //     .slice => {},
                //     else => @compileError("Unable to deserialize type '" ++ @typeName(T) ++ "'"),
                // },
                .array => |info| {
                    var s: T = undefined;
                    for (&s) |*x| {
                        x.* = try self.read(info.child);
                    }
                    return s;
                },
                .vector => |info| {
                    return try self.read([info.len]info.child);
                },
                else => @compileError("Unable to deserialize type '" ++ @typeName(T) ++ "'"),
            },
        }
    }
};

pub const NodeType = struct {
    name: []const u8,
    v_ptr: *anyopaque,
    v_deinit: *const fn (*anyopaque) void,
    v_new: *const fn (*anyopaque, parent: ID) anyerror!ID,
    v_delete: *const fn (*anyopaque, id: ID) anyerror!void,
    v_save: *const fn (*anyopaque, writer: *Writer, id: ID) anyerror!void,
    v_load: *const fn (*anyopaque, reader: *Reader, id: ID) anyerror!void,
    v_get_property: *const fn (*anyopaque, id: ID, name: []const u8) anyerror!?PropertyValue,
    v_set_property: *const fn (*anyopaque, id: ID, name: []const u8, value: PropertyValue) anyerror!void,
};

pub fn NodePool(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        node: *Self,
        mod: *anyopaque,
        type_index: TypeIndex,
        data: std.ArrayList(T),
        ids: std.ArrayList(ID),

        fn init(mod: *Self, module: *anyopaque, type_index: TypeIndex) !@This() {
            return .{ .allocator = mod.allocator, .type_index = type_index, .node = mod, .data = try .initCapacity(mod.allocator, 32), .ids = try .initCapacity(mod.allocator, 32), .mod = module };
        }
        fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
            self.ids.deinit(self.allocator);
        }

        pub fn new(self: *@This(), parent: ID, value: T) !ID {
            // Add entry
            const pool_index: u32 = @intCast(self.data.items.len);
            const id = try self.node.addEntry(parent, pool_index, self.type_index);
            // Add data entry
            const data_ptr = try self.data.addOne(self.allocator);
            const id_ptr = try self.ids.addOne(self.allocator);
            id_ptr.* = id;
            data_ptr.* = value;
            return id;
        }
        fn delete(self: *@This(), id: ID) !void {
            const node = try self.node.getEntry(id);
            // Delete children
            var it = try self.node.iterChildren(id);
            while (it.next()) |child| {
                try self.node.delete(child);
            }
            // Remove node from graph
            try self.node.removeEntry(id);
            if (self.data.items.len > 1) {
                // Update last item before swap remove
                self.node.updateEntry(self.ids.items[self.ids.items.len - 1], node.pool_index);
            }
            // Remove from pool
            _ = self.data.swapRemove(node.pool_index);
            _ = self.ids.swapRemove(node.pool_index);
        }
        pub fn get(self: *@This(), id: ID) !*T {
            const node = try self.node.getEntry(id);
            return &self.data.items[node.pool_index];
        }
    };
}

const ChildIterator = struct {
    self: *Self,
    current: EntryIndex,
    fn init(mod: *Self, id: ID) !@This() {
        return .{
            .self = mod,
            .current = (try mod.getEntry(id)).first_child,
        };
    }
    fn next(it: *@This()) ?ID {
        const index = it.current;
        if (index == 0) return null;
        const entry = it.self.entries.items[index];
        it.current = entry.next;
        return .{
            .index = index,
            .version = entry.version,
        };
    }
};
pub fn iterChildren(self: *Self, id: ID) !ChildIterator {
    return try .init(self, id);
}
pub fn visit(self: *Self, id: ID, visitor: anytype) !void {
    const T = @typeInfo(@TypeOf(visitor)).pointer.child;
    if (@hasDecl(T, "onPreOrder")) {
        try visitor.onPreOrder(id);
    }
    var it = try self.iterChildren(id);
    while (it.next()) |next| {
        try self.visit(next, visitor);
    }
    if (@hasDecl(T, "onPostOrder")) {
        try visitor.onPostOrder(id);
    }
}
pub fn collect(self: *Self, allocator: std.mem.Allocator, id: ID) !std.ArrayList(ID) {
    const Collector = struct {
        nodes: std.ArrayList(ID),
        allocator: std.mem.Allocator,
        fn onPreOrder(collector: *@This(), node: ID) !void {
            try collector.nodes.append(collector.allocator, node);
        }
    };
    var collector = Collector{
        .allocator = allocator,
        .nodes = try .initCapacity(allocator, 32),
    };
    errdefer collector.nodes.deinit(self.allocator);
    try self.visit(id, &collector);
    return collector.nodes;
}

allocator: std.mem.Allocator,
types: std.ArrayList(NodeType),
entries: std.ArrayList(NodeEntry),
free: std.ArrayList(EntryIndex),
nodes: NodePool(EmptyNode),
root: ID,
file: *nux.File,
logger: *nux.Logger,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.types = try .initCapacity(self.allocator, 64);
    self.entries = try .initCapacity(self.allocator, 1024);
    self.free = try .initCapacity(self.allocator, 1024);
    // Reserve index 0 for null id.
    try self.entries.append(self.allocator, .{});
    // Register empty node type.
    try self.registerNodeModule(self);
    // Create root node manually.
    self.root = ID{
        .index = 1,
        .version = 1,
    };
    try self.entries.append(self.allocator, .{
        .type_index = self.nodes.type_index,
        .pool_index = 0,
        .version = self.root.version,
    });
    _ = try self.nodes.data.addOne(self.allocator);
    _ = try self.nodes.ids.append(self.allocator, self.root);
    try self.setName(self.root, "root");
}
pub fn deinit(self: *Self) void {
    self.entries.deinit(self.allocator);
    self.free.deinit(self.allocator);
    for (self.types.items) |typ| {
        typ.v_deinit(typ.v_ptr);
    }
    self.types.deinit(self.allocator);
}

fn addEntry(self: *Self, parent: ID, pool_index: PoolIndex, type_index: TypeIndex) !ID {
    // Check parent
    if (!self.valid(parent)) {
        return error.invalidParent;
    }

    // Find free entry
    var index: EntryIndex = undefined;
    if (self.free.pop()) |idx| {
        index = idx;
    } else {
        index = @intCast(self.entries.items.len);
        const node = try self.entries.addOne(self.allocator);
        node.version = 0;
    }

    // Initialize node
    const node = &self.entries.items[index];
    node.* = .{
        .pool_index = pool_index,
        .type_index = type_index,
        .parent = parent.index,
    };
    const id = ID{
        .index = index,
        .version = node.version,
    };

    // Update parent
    if (parent.index != 0) {
        const p = &self.entries.items[parent.index];
        if (p.last_child != 0) {
            self.entries.items[p.last_child].next = index;
            node.prev = p.last_child;
            p.last_child = index;
        } else {
            p.first_child = index;
            p.last_child = index;
        }
    }

    // Set default name
    var w = std.Io.Writer.fixed(&node.name);
    try w.print("node{d}", .{id.value()});
    node.name_len = w.end;

    return id;
}
fn removeEntry(self: *Self, id: ID) !void {
    var node = &self.entries.items[id.index];
    // Remove from parent
    if (node.parent != 0) {
        const p = &self.entries.items[node.parent];
        if (p.first_child == id.index) {
            p.first_child = node.next;
        }
        if (p.last_child == id.index) {
            p.last_child = node.prev;
        }
        if (node.next != 0) {
            self.entries.items[node.next].prev = node.prev;
        }
        if (node.prev != 0) {
            self.entries.items[node.prev].next = node.next;
        }
    }
    // Update version and add to freelist
    node.version += 1;
    (try self.free.addOne(self.allocator)).* = id.index;
}
fn updateEntry(self: *Self, id: ID, pool_index: PoolIndex) void {
    self.entries.items[id.index].pool_index = pool_index;
}
fn getEntry(self: *Self, id: ID) !*NodeEntry {
    if (id.isNull()) {
        return error.nullId;
    }
    if (id.index >= self.entries.items.len) {
        return error.invalidIndex;
    }
    const node = &self.entries.items[id.index];
    if (node.version != id.version) {
        return error.invalidVersion;
    }
    return node;
}

pub fn getRoot(self: *Self) ID {
    return self.root;
}
pub fn registerNodeModule(self: *Self, module: anytype) !void {
    const field_name = "nodes";
    const T = @typeInfo(@TypeOf(module)).pointer.child;
    if (@hasField(T, field_name)) {

        // Init pool
        const type_index: TypeIndex = @intCast(self.types.items.len);
        @field(module, field_name) = try .init(self, module, type_index);

        // Create vtable
        const gen = struct {
            fn deinit(pointer: *anyopaque) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                @field(mod, field_name).deinit();
            }
            fn new(pointer: *anyopaque, parent: ID) !ID {
                const mod: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "new")) {
                    return try mod.new(parent);
                } else {
                    return try @field(mod, field_name).new(parent, .{});
                }
            }
            fn delete(pointer: *anyopaque, id: ID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "delete") and T != Self) {
                    return try mod.delete(id);
                } else {
                    return @field(mod, field_name).delete(id);
                }
            }
            fn save(pointer: *anyopaque, writer: *Writer, id: ID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "save")) {
                    return try mod.save(id, writer);
                }
            }
            fn load(pointer: *anyopaque, reader: *Reader, id: ID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "load")) {
                    try mod.load(id, reader);
                }
            }
            fn setProperty(pointer: *anyopaque, id: ID, name: []const u8, value: PropertyValue) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "setProperty")) {
                    const enu = std.meta.stringToEnum(T.Property, name) orelse return error.invalidPropertyName;
                    try mod.setProperty(id, enu, value);
                }
            }
            fn getProperty(pointer: *anyopaque, id: ID, name: []const u8) !?PropertyValue {
                const mod: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(T, "getProperty")) {
                    const enu = std.meta.stringToEnum(T.Property, name) orelse return null;
                    return try mod.getProperty(id, enu);
                }
                return null;
            }
        };

        // Register type
        var it = std.mem.splitBackwardsScalar(u8, @typeName(T), '.');
        const name = it.first();
        (try self.types.addOne(self.allocator)).* = .{
            .name = name,
            .v_ptr = module,
            .v_deinit = gen.deinit,
            .v_new = gen.new,
            .v_delete = gen.delete,
            .v_save = gen.save,
            .v_load = gen.load,
            .v_get_property = gen.getProperty,
            .v_set_property = gen.setProperty,
        };
    }
}

pub fn newFromType(self: *Self, parent: ID, typename: []const u8) !ID {
    const typ = try self.findType(typename);
    return typ.v_new(typ.v_ptr, parent);
}
pub fn new(self: *Self, parent: ID) !ID {
    return (try self.nodes.new(parent, .{}));
}
pub fn newPath(self: *Self, base: ID, path: []const u8) !ID {
    var it = std.mem.splitScalar(u8, path, '/');
    var node = base;
    while (it.next()) |part| {
        if (self.findChild(node, part)) |child| {
            node = child;
        } else |_| {
            node = try self.new(node);
            try self.setName(node, part);
        }
    }
    return node;
}
pub fn delete(self: *Self, id: ID) !void {
    const typ = try self.getType(id);
    return typ.v_delete(typ.v_ptr, id);
}
pub fn valid(self: *Self, id: ID) bool {
    _ = self.getEntry(id) catch return false;
    return true;
}
pub fn getParent(self: *Self, id: ID) !ID {
    const node = try self.getEntry(id);
    if (node.parent != 0) {
        return .{
            .index = node.parent,
            .version = self.entries.items[node.parent].version,
        };
    }
    return error.noParent;
}
pub fn getType(self: *Self, id: ID) !*NodeType {
    const node = try self.getEntry(id);
    return &self.types.items[node.type_index];
}
pub fn findType(self: *Self, name: []const u8) !*NodeType {
    for (self.types.items) |*typ| {
        if (std.mem.eql(u8, name, typ.name)) {
            return typ;
        }
    }
    return error.unknownType;
}
pub fn find(self: *Self, relativeTo: ID, path: []const u8) !ID {
    const entry = try self.getEntry(relativeTo);
    _ = entry;
    var it = std.mem.splitScalar(u8, path, '/');
    var ret = relativeTo;
    while (it.next()) |part| {
        if (part.len > 0) {
            if (part[0] == '$') {
                ret = try self.findFirstChildType(ret, part[1..]);
            } else {
                ret = try self.findChild(ret, part);
            }
        }
    }
    return ret;
}
pub fn findGlobal(self: *Self, path: []const u8) !ID {
    return self.find(self.getRoot(), path);
}
pub fn findFirstChildType(self: *Self, id: ID, typename: []const u8) !ID {
    var it = try self.iterChildren(id);
    while (it.next()) |child| {
        const typ = try self.getType(child);
        if (std.mem.eql(u8, typ.name, typename)) {
            return child;
        }
    }
    return error.childNotFound;
}
pub fn findChild(self: *Self, id: ID, name: []const u8) !ID {
    var it = try self.iterChildren(id);
    while (it.next()) |child| {
        if (std.mem.eql(u8, try self.getName(child), name)) {
            return child;
        }
    }
    return error.childNotFound;
}
pub fn setName(self: *Self, id: ID, name: []const u8) !void {
    const entry = try self.getEntry(id);
    if (self.getParent(id)) |parent| {
        // TODO implement bloom filter to optimize O(1)
        var it = try self.iterChildren(parent);
        while (it.next()) |child| {
            if (child != id) {
                if (std.mem.eql(u8, name, try self.getName(child))) {
                    return error.duplicatedName;
                }
            }
        }
    } else |_| {}
    entry.setName(name);
}
pub fn getName(self: *Self, id: ID) ![]const u8 {
    const entry = try self.getEntry(id);
    return entry.getName();
}
fn writeEntryPath(self: *Self, entry: *NodeEntry, writer: *std.Io.Writer) !void {
    if (entry.parent == 0) { // root node
        return;
    }
    try self.writeEntryPath(&self.entries.items[entry.parent], writer);
    _ = try writer.write("/");
    _ = try writer.write(entry.getName());
}
fn writePath(self: *Self, id: ID, writer: *std.Io.Writer) !void {
    const entry = try self.getEntry(id);
    if (self.root == id) {
        _ = try writer.write("/");
    } else {
        try self.writeEntryPath(entry, writer);
    }
}

const Dumper = struct {
    node: *Self,
    depth: u32 = 0,
    header: [256]u8 = undefined,
    // header_len: usize = 0,
    fn onPreOrder(self: *@This(), id: ID) !void {
        const entry = try self.node.getEntry(id);
        const typ = self.node.types.items[entry.type_index];
        // Append header
        if (entry.next != 0) {
            self.header[self.depth] = 0;
        } else {
            self.header[self.depth] = 1;
        }
        // Print header
        var buf: [256]u8 = undefined;
        var w = std.Io.Writer.fixed(&buf);
        for (1..(self.depth + 1)) |i| {
            switch (self.header[i]) {
                0 => try w.print("├─ ", .{}),
                1 => try w.print("└─ ", .{}),
                2 => try w.print("│  ", .{}),
                3 => try w.print("   ", .{}),
                else => {},
            }
        }
        // Replace header.
        if (entry.next != 0) {
            self.header[self.depth] = 2;
        } else {
            self.header[self.depth] = 3;
        }
        // Print entry.
        self.node.logger.info("{s}\x1b[36m{s}\x1b[37m \x1b[31m{s}\x1b[37m", .{ buf[0..w.end], entry.getName(), typ.name });
        self.depth += 1;
    }
    fn onPostOrder(self: *@This(), _: ID) !void {
        self.depth -= 1;
    }
};
pub fn dump(self: *Self, id: ID) void {
    var dumper = Dumper{ .node = self };
    self.visit(id, &dumper) catch {};
}

pub fn exportNode(self: *Self, id: ID, path: []const u8) !void {
    var buf: [512]u8 = undefined;
    var file_writer: nux.File.Writer = try .open(self.file, path, &buf);
    defer file_writer.close();
    // Collect nodes
    var nodes = try self.collect(self.allocator, id);
    defer nodes.deinit(self.allocator);
    // Collect types
    var types: std.ArrayList([]const u8) = try .initCapacity(self.allocator, 64);
    defer types.deinit(self.allocator);
    for (nodes.items) |node| {
        const typ = try self.getType(node);
        var found = false;
        for (types.items) |t| {
            if (std.mem.eql(u8, typ.name, t)) {
                found = true;
                break;
            }
        }
        if (!found) {
            try types.append(self.allocator, typ.name);
        }
    }
    // Initialize writer
    var writer: Writer = .{
        .node = self,
        .writer = &file_writer.interface,
        .nodes = nodes.items,
    };
    // Write type table
    try writer.write(@as(u32, @intCast(types.items.len)));
    for (types.items) |typ| {
        try writer.write(typ);
    }
    // Write node table
    try writer.write(@as(u32, @intCast(nodes.items.len)));
    for (nodes.items) |node| {
        // Find parent index
        // 0 => no local parent, only valid for root node
        var parent_index: u32 = 0;
        if (self.getParent(node)) |parent| {
            for (nodes.items, 0..) |item, index| {
                if (item == parent) {
                    parent_index = @intCast(index + 1);
                    break;
                }
            }
        } else |_| {}
        // Find type index
        const typ = try self.getType(node);
        var type_index: u32 = undefined;
        for (types.items, 0..) |t, index| {
            if (std.mem.eql(u8, t, typ.name)) {
                type_index = @intCast(index);
            }
        }
        try writer.write(type_index);
        try writer.write(parent_index);
        try writer.write(try self.getName(node));
    }
    // Write nodes data
    for (nodes.items) |node| {
        const typ = try self.getType(node);
        try typ.v_save(typ.v_ptr, &writer, node);
    }
}
pub fn importNode(self: *Self, parent: ID, path: []const u8) !ID {
    // Read entry
    const data = try self.file.read(path, self.allocator);
    defer self.allocator.free(data);
    var data_reader = std.Io.Reader.fixed(data);
    var reader: Reader = .{
        .reader = &data_reader,
        .node = self,
        .nodes = &.{},
    };
    // Read type table
    const type_table_len = try reader.read(u32);
    if (type_table_len == 0) return error.emptyNodeFile;
    const type_table = try self.allocator.alloc(*const NodeType, type_table_len);
    defer self.allocator.free(type_table);
    for (0..type_table_len) |index| {
        const typename = try reader.takeBytes();
        type_table[index] = self.findType(typename) catch {
            return error.nodeTypeNotFound;
        };
    }
    // Read node table
    const node_count = try reader.read(u32);
    var nodes = try self.allocator.alloc(ID, node_count);
    defer self.allocator.free(nodes);
    reader.nodes = nodes;
    for (0..node_count) |index| {
        const type_index = try reader.read(u32);
        if (type_index > type_table_len) {
            return error.invalidTypeIndex;
        }
        const parent_index = try reader.read(u32);
        if (parent_index > nodes.len + 1) {
            return error.invalidParentIndex;
        }
        const name = try reader.takeBytes();
        const parent_node = if (parent_index != 0) nodes[parent_index - 1] else parent;
        const typ = type_table[type_index];
        nodes[index] = try typ.v_new(typ.v_ptr, parent_node);
        if (index != 0) { // Do not rename root node
            try self.setName(nodes[index], name);
        }
    }
    // Read node data
    for (nodes) |node| {
        const typ = try self.getType(node);
        try typ.v_load(typ.v_ptr, &reader, node);
    }
    return nodes[0];
}
