const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const Version = u8;
pub const NodeIndex = u24;
pub const ComponentIndex = u32;
pub const ComponentID = u8;

pub const max_component = 128;

pub const ComponentType = struct {
    name: []const u8,
    v_ptr: *anyopaque,
    v_deinit: *const fn (*anyopaque) void,
    v_add: *const fn (*anyopaque, id: nux.ID) anyerror!void,
    v_remove: *const fn (*anyopaque, id: nux.ID) void,
    v_has: *const fn (*anyopaque, id: nux.ID) bool,
    v_save: *const fn (*anyopaque, id: nux.ID, writer: *Writer) anyerror!void,
    v_load: *const fn (*anyopaque, id: nux.ID, reader: *Reader) anyerror!void,
    v_description: *const fn (*anyopaque, id: ID, w: *std.Io.Writer) anyerror!void,
};

pub fn Components(T: type) type {
    return struct {
        id: ComponentID,
        allocator: std.mem.Allocator,
        data: std.ArrayList(union {
            used: struct {
                data: T,
                id: nux.ID,
            },
            free: ?ComponentIndex,
        }) = .empty,
        bitset: std.DynamicBitSet,
        free_index: ?ComponentIndex = null,
        node: *Self,

        pub const ComponentIterator = struct {
            components: *Components(T),
            iterator: std.DynamicBitSet.Iterator(.{}),
            fn init(components: *Components(T)) @This() {
                return .{
                    .components = components,
                    .iterator = components.bitset.iterator(.{}),
                };
            }
            pub fn next(self: *@This()) ?*T {
                const index = self.iterator.next() orelse return null;
                return &self.components.data.items[index].used.data;
            }
        };

        fn init(allocator: std.mem.Allocator, node: *Self, type_index: ComponentID) !@This() {
            return .{
                .allocator = allocator,
                .node = node,
                .data = .empty,
                .bitset = try .initEmpty(allocator, 128),
                .id = type_index,
            };
        }
        fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
            self.bitset.deinit();
        }
        pub fn add(self: *@This(), id: nux.ID) !void {
            _ = try self.addPtr(id);
        }
        pub fn addPtr(self: *@This(), id: nux.ID) !*T {
            // Check node entry
            const entry = try self.node.getEntry(id);
            var index: ComponentIndex = undefined;
            if (entry.components[self.id]) |previous_index| {
                // Reuse index
                index = previous_index;
                // Deinit previous component
                const data = &self.data.items[@intCast(index)].used.data;
                if (@hasDecl(T, "deinit")) {
                    T.deinit(@fieldParentPtr("components", self), data);
                }
            } else {
                // Create new index
                index = @intCast(self.data.items.len);
                if (self.free_index) |free| {
                    index = free;
                    self.free_index = self.data.items[@intCast(free)].free;
                } else {
                    _ = try self.data.addOne(self.allocator);
                }
            }
            // Initialize component
            var data: T = undefined;
            if (@hasDecl(T, "init")) {
                data = try T.init(@fieldParentPtr("components", self));
            } else {
                data = .{};
            }
            self.data.items[@intCast(index)] = .{ .used = .{
                .data = data,
                .id = id,
            } };
            self.bitset.set(@intCast(index));
            entry.components[@intCast(self.id)] = index;
            return &self.data.items[@intCast(index)].used.data;
        }
        pub fn remove(self: *@This(), id: ID) void {
            const entry = self.node.getEntry(id) catch return;
            if (entry.components[self.id]) |index| {
                // Deinit component
                const data = &self.data.items[@intCast(index)].used.data;
                if (@hasDecl(T, "deinit")) {
                    T.deinit(@fieldParentPtr("components", self), data);
                }
                // Remove from pool
                self.data.items[@intCast(index)] = .{ .free = self.free_index };
                self.free_index = index;
                self.bitset.unset(@intCast(index));
                // Unset index
                entry.components[self.id] = null;
            }
        }
        fn getFromIndex(self: *@This(), index: ComponentIndex) !*T {
            return &self.data.items[index].used.data;
        }
        pub fn values(self: *@This()) ComponentIterator {
            return .init(self);
        }
        pub fn getOptional(self: *@This(), id: nux.ID) ?*T {
            const index = self.node.getComponentIndex(id, self.id) orelse return null;
            return try self.getFromIndex(index);
        }
        pub fn get(self: *@This(), id: nux.ID) !*T {
            return self.getOptional(id) orelse return error.ComponentNotFound;
        }
        pub fn has(self: *@This(), id: nux.ID) bool {
            return self.getOptional(id) != null;
        }
    };
}

pub const PropertyValue = union(enum) {
    id: nux.ID,
    vec2: nux.Vec2,
    vec3: nux.Vec3,
    vec4: nux.Vec4,
    quat: nux.Quat,
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
    index: NodeIndex,
};

const NodeEntry = struct {
    const max_name: usize = 64;
    version: Version = 1,
    parent: NodeIndex = 0,
    prev: NodeIndex = 0,
    next: NodeIndex = 0,
    first_child: NodeIndex = 0,
    last_child: NodeIndex = 0,
    name: [max_name]u8 = undefined,
    name_len: usize = 0,
    components: [max_component]?ComponentIndex = .{null} ** max_component,

    fn getName(self: *@This()) []const u8 {
        return self.name[0..self.name_len];
    }
    fn setName(self: *@This(), name: []const u8) void {
        self.name_len = @min(name.len, self.name.len);
        @memcpy(self.name[0..self.name_len], name[0..self.name_len]);
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
                if (self.node.exists(v)) {
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
                    try self.writer.writeByte(@intFromBool(v));
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

const ChildIterator = struct {
    self: *Self,
    current: NodeIndex,
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
component_types: std.ArrayList(ComponentType),
entries: std.ArrayList(NodeEntry),
free: std.ArrayList(NodeIndex),
root: ID,
file: *nux.File,
logger: *nux.Logger,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.component_types = try .initCapacity(self.allocator, 64);
    self.entries = try .initCapacity(self.allocator, 1024);
    self.free = try .initCapacity(self.allocator, 1024);
    // Reserve index 0 for null id.
    try self.entries.append(self.allocator, .{});
    // Create root node manually.
    self.root = ID{
        .index = 1,
        .version = 1,
    };
    try self.entries.append(self.allocator, .{
        .version = self.root.version,
    });
    try self.setName(self.root, "root");
}
pub fn deinit(self: *Self) void {
    self.entries.deinit(self.allocator);
    self.free.deinit(self.allocator);
    for (self.component_types.items) |typ| {
        typ.v_deinit(typ.v_ptr);
    }
    self.component_types.deinit(self.allocator);
}

fn addEntry(self: *Self, parent: ID) !ID {
    // Check parent
    if (!self.exists(parent)) {
        return error.invalidParent;
    }

    // Find free entry
    var index: NodeIndex = undefined;
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

fn getComponentIndex(self: *Self, id: nux.ID, type_index: ComponentID) ?ComponentIndex {
    const entry = self.getEntry(id) catch return null;
    return entry.components[@intCast(type_index)];
}
fn findComponentType(self: *Self, name: []const u8) !*ComponentType {
    for (self.component_types.items) |*typ| {
        if (std.mem.eql(u8, typ.name, name)) {
            return typ;
        }
    }
    return error.ComponentTypeNotFound;
}
pub fn getRoot(self: *Self) ID {
    return self.root;
}
pub fn registerComponentModule(self: *Self, module: anytype) !void {
    const field_name = "components";
    const T = @typeInfo(@TypeOf(module)).pointer.child;
    if (@hasField(T, field_name)) {

        // Init pool
        const component_id: ComponentID = @intCast(self.component_types.items.len);
        @field(module, field_name) = try .init(self.allocator, self, component_id);

        // Create vtable
        const gen = struct {
            fn deinit(pointer: *anyopaque) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                @field(mod, field_name).deinit();
            }
            fn add(pointer: *anyopaque, id: nux.ID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                _ = try @field(mod, field_name).add(id);
            }
            fn remove(pointer: *anyopaque, id: nux.ID) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                @field(mod, field_name).remove(id);
            }
            fn has(pointer: *anyopaque, id: nux.ID) bool {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return @field(mod, field_name).has(id);
            }
            fn save(pointer: *anyopaque, id: ID, writer: *Writer) !void {
                // const mod: *T = @ptrCast(@alignCast(pointer));
                // try @field(mod, field_name).save(id, writer);
                _ = pointer;
                _ = id;
                _ = writer;
            }
            fn load(pointer: *anyopaque, id: ID, reader: *Reader) !void {
                // const mod: *T = @ptrCast(@alignCast(pointer));
                // if (@hasDecl(T, "load")) {
                //     try mod.load(id, reader);
                // }
                _ = pointer;
                _ = id;
                _ = reader;
            }
            fn shortDescription(pointer: *anyopaque, id: ID, writer: *std.Io.Writer) !void {
                _ = pointer;
                _ = id;
                _ = writer;
            }
        };

        // Register type
        var it = std.mem.splitBackwardsScalar(u8, @typeName(T), '.');
        const name = it.first();
        (try self.component_types.addOne(self.allocator)).* = .{
            .name = name,
            .v_ptr = module,
            .v_deinit = gen.deinit,
            .v_add = gen.add,
            .v_remove = gen.remove,
            .v_has = gen.has,
            .v_save = gen.save,
            .v_load = gen.load,
            .v_description = gen.shortDescription,
        };
    }
}

pub fn create(self: *Self, parent: ID) !ID {
    return self.addEntry(parent);
}
pub fn createNamed(self: *Self, parent: ID, name: []const u8) !ID {
    const id = try self.create(parent);
    try self.setName(parent, name);
    return id;
}
pub fn createPath(self: *Self, base: ID, path: []const u8) !ID {
    var it = std.mem.splitScalar(u8, path, '/');
    var node = base;
    while (it.next()) |part| {
        if (self.findChild(node, part)) |child| {
            node = child;
        } else |_| {
            node = try self.create(node);
            try self.setName(node, part);
        }
    }
    return node;
}
pub fn delete(self: *Self, id: ID) !void {
    // Delete children
    var it = try self.iterChildren(id);
    while (it.next()) |child| {
        try self.delete(child);
    }
    // Delete entry
    const entry = try self.getEntry(id);
    // Remove components
    for (entry.components, 0..) |component, type_index| {
        if (component != null) {
            const typ = &self.component_types.items[type_index];
            typ.v_remove(typ.v_ptr, id);
        }
    }
}
pub fn exists(self: *Self, id: ID) bool {
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
pub fn find(self: *Self, relativeTo: ID, path: []const u8) !ID {
    const entry = try self.getEntry(relativeTo);
    _ = entry;
    var it = std.mem.splitScalar(u8, path, '/');
    var ret = relativeTo;
    while (it.next()) |part| {
        if (part.len > 0) {
            ret = try self.findChild(ret, part);
        }
    }
    return ret;
}
pub fn findGlobal(self: *Self, path: []const u8) !ID {
    return self.find(self.getRoot(), path);
}
// pub fn findFirstChildType(self: *Self, id: ID, typename: []const u8) !ID {
//     var it = try self.iterChildren(id);
//     while (it.next()) |child| {
//         const typ = try self.getType(child);
//         if (std.mem.eql(u8, typ.name, typename)) {
//             return child;
//         }
//     }
//     return error.ChildNotFound;
// }
pub fn findChild(self: *Self, id: ID, name: []const u8) !ID {
    var it = try self.iterChildren(id);
    while (it.next()) |child| {
        if (std.mem.eql(u8, try self.getName(child), name)) {
            return child;
        }
    }
    return error.ChildNotFound;
}
pub fn setNameFormat(
    self: *Self,
    id: ID,
    comptime format: []const u8,
    args: anytype,
) !void {
    var buf: [NodeEntry.max_name]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);
    try w.print(format, args);
    try self.setName(id, buf[0..w.end]);
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

    fn writeHeader(self: *@This(), w: *std.Io.Writer) !void {
        for (1..(self.depth + 1)) |i| {
            switch (self.header[i]) {
                0 => try w.print("├─ ", .{}),
                1 => try w.print("└─ ", .{}),
                2 => try w.print("│  ", .{}),
                3 => try w.print("   ", .{}),
                else => {},
            }
        }
    }

    fn printComponents(self: *@This(), id: ID) !void {
        // Print header
        var buf: [256]u8 = undefined;
        var w = std.Io.Writer.fixed(&buf);
        try self.writeHeader(&w);
        const entry = try self.node.getEntry(id);
        for (entry.components, 0..) |component, type_index| {
            if (component != null) {
                const typ = self.node.component_types.items[type_index];

                // Write type
                try w.print("\x1b[31m", .{}); // red
                try w.print("{s} ", .{typ.name});

                // Write description
                try w.print("\x1b[90m", .{}); // light gray
                try typ.v_description(typ.v_ptr, id, &w);
                try w.print("\x1b[37m", .{}); // white
            }
        }
        self.node.logger.info("{s}", .{buf[0..w.end]});
    }

    fn onPreOrder(self: *@This(), id: ID) !void {
        const entry = try self.node.getEntry(id);

        // Append header
        if (entry.next != 0) {
            self.header[self.depth] = 0;
        } else {
            self.header[self.depth] = 1;
        }

        // Print header
        var buf: [256]u8 = undefined;
        var w = std.Io.Writer.fixed(&buf);
        try self.writeHeader(&w);

        // Replace header
        if (entry.next != 0) {
            self.header[self.depth] = 2;
        } else {
            self.header[self.depth] = 3;
        }

        // Write name
        try w.print("\x1b[36m", .{}); // cyan
        try w.print("{s} ", .{entry.getName()});
        try w.print("\x1b[37m", .{}); // white

        // Print components
        try self.printComponents(id);

        // Print entry
        self.node.logger.info("{s}", .{buf[0..w.end]});
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

// pub fn exportNode(self: *Self, id: ID, path: []const u8) !void {
//     var buf: [512]u8 = undefined;
//     var file_writer: nux.File.Writer = try .open(self.file, path, &buf);
//     defer file_writer.close();
//     // Collect nodes
//     var nodes = try self.collect(self.allocator, id);
//     defer nodes.deinit(self.allocator);
//     // Collect types
//     var types: std.ArrayList([]const u8) = try .initCapacity(self.allocator, 64);
//     defer types.deinit(self.allocator);
//     for (nodes.items) |node| {
//         const typ = try self.getType(node);
//         var found = false;
//         for (types.items) |t| {
//             if (std.mem.eql(u8, typ.name, t)) {
//                 found = true;
//                 break;
//             }
//         }
//         if (!found) {
//             try types.append(self.allocator, typ.name);
//         }
//     }
//     // Initialize writer
//     var writer: Writer = .{
//         .node = self,
//         .writer = &file_writer.interface,
//         .nodes = nodes.items,
//     };
//     // Write type table
//     try writer.write(@as(u32, @intCast(types.items.len)));
//     for (types.items) |typ| {
//         try writer.write(typ);
//     }
//     // Write node table
//     try writer.write(@as(u32, @intCast(nodes.items.len)));
//     for (nodes.items) |node| {
//         // Find parent index
//         // 0 => no local parent, only valid for root node
//         var parent_index: u32 = 0;
//         if (self.getParent(node)) |parent| {
//             for (nodes.items, 0..) |item, index| {
//                 if (item == parent) {
//                     parent_index = @intCast(index + 1);
//                     break;
//                 }
//             }
//         } else |_| {}
//         // Find type index
//         const typ = try self.getType(node);
//         var type_index: u32 = undefined;
//         for (types.items, 0..) |t, index| {
//             if (std.mem.eql(u8, t, typ.name)) {
//                 type_index = @intCast(index);
//             }
//         }
//         try writer.write(type_index);
//         try writer.write(parent_index);
//         try writer.write(try self.getName(node));
//     }
//     // Write nodes data
//     for (nodes.items) |node| {
//         const typ = try self.getType(node);
//         try typ.v_save(typ.v_ptr, &writer, node);
//     }
// }
// pub fn importNode(self: *Self, parent: ID, path: []const u8) !ID {
//     // Read entry
//     const data = try self.file.read(path, self.allocator);
//     defer self.allocator.free(data);
//     var data_reader = std.Io.Reader.fixed(data);
//     var reader: Reader = .{
//         .reader = &data_reader,
//         .node = self,
//         .nodes = &.{},
//     };
//     // Read component type table
//     const type_table_len = try reader.read(u32);
//     if (type_table_len == 0) return error.EmptyTypeTable;
//     const type_table = try self.allocator.alloc(*const ComponentType, type_table_len);
//     defer self.allocator.free(type_table);
//     for (0..type_table_len) |index| {
//         const typename = try reader.takeBytes();
//         type_table[index] = self.findComponentType(typename) catch {
//             return error.NodeTypeNotFound;
//         };
//     }
//     // Read node table
//     const node_count = try reader.read(u32);
//     var nodes = try self.allocator.alloc(ID, node_count);
//     defer self.allocator.free(nodes);
//     reader.nodes = nodes;
//     for (0..node_count) |index| {
//         const type_index = try reader.read(u32);
//         if (type_index > type_table_len) {
//             return error.invalidTypeIndex;
//         }
//         const parent_index = try reader.read(u32);
//         if (parent_index > nodes.len + 1) {
//             return error.invalidParentIndex;
//         }
//         const name = try reader.takeBytes();
//         const parent_node = if (parent_index != 0) nodes[parent_index - 1] else parent;
//         const typ = type_table[type_index];
//         nodes[index] = try typ.v_add(typ.v_ptr, parent_node);
//         if (index != 0) { // Do not rename root node
//             try self.setName(nodes[index], name);
//         }
//     }
//     // Read node data
//     for (nodes) |node| {
//         const typ = try self.getType(node);
//         try typ.v_load(typ.v_ptr, &reader, node);
//     }
//     return nodes[0];
// }
