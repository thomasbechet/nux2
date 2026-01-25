const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const Version = u8;
pub const EntryIndex = u24;
pub const PoolIndex = u32;
pub const TypeIndex = u32;

pub const NodeID = packed struct(u32) {
    pub const @"null" = @This(){ .version = 0, .index = 0 };

    pub fn isNull(self: *const @This()) bool {
        return self.index == 0;
    }
    pub fn setNull(self: *@This()) void {
        self.index = 0;
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
    child: EntryIndex = 0,
};

pub const Writer = struct {
    writer: *std.Io.Writer,
    node: *Self,

    pub fn write(self: *@This(), v: anytype) !void {
        const T = @TypeOf(v);
        switch (T) {
            nux.NodeID => {
                if (self.node.valid(v)) {
                    // TODO find the node id in the written nodes to find its index
                } else {
                    self.write(null);
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
                    // try self.writer.writeInt(T, v, .little);
                    try self.writer.writeLeb128(v);
                },
                .float, .comptime_float => {
                    // try self.writer.writeInt(u32, @bitCast(v), .little);
                    try self.writer.writeLeb128(@as(u32, @bitCast(v)));
                },
                .bool => {
                    try self.writer.writeByte(@bitCast(v));
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
                        // try self.write(@as(u32, @intCast(v.len)));
                        try self.writer.writeLeb128(@as(u32, @intCast(v.len)));
                        for (v) |x| {
                            try self.write(x);
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

    pub fn readString(self: *@This()) ![]u8 {
        const size = try self.read(u32);
        return try self.reader.take(size);
    }
    pub fn read(self: *@This(), comptime T: type) !T {
        switch (T) {
            nux.NodeID => {
                const data = self.reader.takeInt(u32, .little);
                if (data != 0) {
                    return data;
                } else {
                    return NodeID.null;
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
                    // return try self.reader.takeInt(T, .little);
                    return try self.reader.takeLeb128(T);
                },
                .float, .comptime_float => {
                    // return @as(T, @bitCast(try self.reader.takeInt(u32, .little)));
                    return @as(T, @bitCast(try self.reader.takeLeb128(u32)));
                },
                .bool => {
                    return try self.reader.takeByte();
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
                .pointer => |info| switch (info.size) {
                    // .one => {
                    //     return self.write(v.*);
                    //     const slice = try allocator.alloc(info.child, size);
                    // },
                    .slice => {},
                    else => @compileError("Unable to deserialize type '" ++ @typeName(T) ++ "'"),
                },
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
    v_new: *const fn (*anyopaque, parent: NodeID) anyerror!NodeID,
    v_delete: *const fn (*anyopaque, id: NodeID) anyerror!void,
    v_deinit: *const fn (*anyopaque) void,
    v_save: *const fn (*anyopaque, writer: *Writer, id: NodeID) anyerror!void,
    v_load: *const fn (*anyopaque, reader: *Reader, id: NodeID) anyerror!void,
};

pub fn NodePool(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        node: *Self,
        mod: *anyopaque,
        type_index: TypeIndex,
        data: std.ArrayList(T),
        ids: std.ArrayList(NodeID),

        fn init(node: *Self, mod: *anyopaque, type_index: TypeIndex) !@This() {
            return .{ .allocator = node.allocator, .type_index = type_index, .node = node, .data = try .initCapacity(node.allocator, 32), .ids = try .initCapacity(node.allocator, 32), .mod = mod };
        }
        fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
            self.ids.deinit(self.allocator);
        }

        pub fn new(self: *@This(), parent: NodeID) !struct { id: NodeID, data: *T } {
            // Add entry
            const pool_index = self.data.items.len;
            const id = try self.node.addEntry(parent, @intCast(pool_index), self.type_index);
            // Add data entry
            const data_ptr = try self.data.addOne(self.allocator);
            const id_ptr = try self.ids.addOne(self.allocator);
            id_ptr.* = id;
            // Init node
            if (@hasDecl(T, "init")) {
                data_ptr.* = try T.init(@ptrCast(@alignCast(self.mod)));
            }
            return .{ .id = id, .data = data_ptr };
        }
        fn delete(self: *@This(), id: NodeID) !void {
            const node = try self.node.getEntry(id);
            // Delete children
            var it = try self.node.iterChildren(id);
            while (it.next()) |child| {
                try self.node.delete(child);
            }
            // Deinit node
            if (@hasDecl(T, "deinit")) {
                T.deinit(@ptrCast(@alignCast(self.mod)), &self.data.items[node.pool_index]);
            }
            // Remove node from graph
            try self.node.removeEntry(id);
            // Update last item before swap remove
            self.node.updateEntry(self.ids.items[node.pool_index], node.pool_index);
            // Remove from pool
            _ = self.data.swapRemove(node.pool_index);
            _ = self.ids.swapRemove(node.pool_index);
        }
        pub fn get(self: *@This(), id: NodeID) !*T {
            const node = try self.node.getEntry(id);
            return &self.data.items[node.pool_index];
        }
        pub fn save(self: *@This(), writer: *Writer, id: NodeID) !void {
            const node = try self.node.getEntry(id);
            if (@hasDecl(T, "save")) {
                try T.save(@ptrCast(@alignCast(self.mod)), writer, &self.data.items[node.pool_index]);
            }
        }
        pub fn load(self: *@This(), reader: *Reader, id: NodeID) !void {
            const node = try self.node.getEntry(id);
            if (@hasDecl(T, "save")) {
                try T.load(@ptrCast(@alignCast(self.mod)), reader, &self.data.items[node.pool_index]);
            }
        }
    };
}

const ChildIterator = struct {
    self: *Self,
    current: EntryIndex,
    fn init(self: *Self, id: NodeID) !@This() {
        return .{
            .self = self,
            .current = (try self.getEntry(id)).child,
        };
    }
    fn next(it: *@This()) ?NodeID {
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
pub fn iterChildren(self: *Self, id: NodeID) !ChildIterator {
    return try .init(self, id);
}
pub fn visit(self: *Self, id: NodeID, visitor: anytype) !void {
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
pub fn collect(self: *Self, allocator: std.mem.Allocator, id: NodeID) !std.ArrayList(NodeID) {
    const Collector = struct {
        nodes: std.ArrayList(NodeID),
        allocator: std.mem.Allocator,
        fn onPreOrder(collector: *@This(), node: NodeID) !void {
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
empty_nodes: NodePool(struct { dummy: u32 }),
root: NodeID,
disk: *nux.Disk,
logger: *nux.Logger,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.types = try .initCapacity(self.allocator, 64);
    self.entries = try .initCapacity(self.allocator, 1024);
    self.free = try .initCapacity(self.allocator, 1024);
    // Reserve index 0 for null id.
    try self.entries.append(self.allocator, .{});
    // Register empty node type.
    try self.registerNodeModule(Self, "empty_nodes", self);
    // Create root node.
    self.root = NodeID{
        .index = 1,
        .version = 1,
    };
    try self.entries.append(self.allocator, .{
        .type_index = self.empty_nodes.type_index,
        .pool_index = 0,
        .version = self.root.version,
    });
    _ = try self.empty_nodes.data.addOne(self.allocator);
    _ = try self.empty_nodes.ids.append(self.allocator, self.root);
}
pub fn deinit(self: *Self) void {
    self.entries.deinit(self.allocator);
    self.free.deinit(self.allocator);
    for (self.types.items) |typ| {
        typ.v_deinit(typ.v_ptr);
    }
    self.types.deinit(self.allocator);
}

fn addEntry(self: *Self, parent: NodeID, pool_index: PoolIndex, type_index: TypeIndex) !NodeID {
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
    const id = NodeID{
        .index = index,
        .version = node.version,
    };

    // Update parent
    if (parent.index != 0) {
        const p = &self.entries.items[parent.index];
        if (p.child != 0) {
            self.entries.items[p.child].prev = index;
            node.next = p.child;
        }
        p.child = index;
    }
    return id;
}
fn removeEntry(self: *Self, id: NodeID) !void {
    var node = &self.entries.items[id.index];
    // remove from parent
    if (node.parent != 0) {
        const p = &self.entries.items[node.parent];
        if (p.child == id.index) {
            p.child = node.next;
        }
    }
    // Update version and add to freelist
    node.version += 1;
    (try self.free.addOne(self.allocator)).* = id.index;
}
fn updateEntry(self: *Self, id: NodeID, pool_index: PoolIndex) void {
    self.entries.items[id.index].pool_index = pool_index;
}
fn getEntry(self: *Self, id: NodeID) !*NodeEntry {
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

pub fn getRoot(self: *Self) NodeID {
    return self.root;
}
pub fn registerNodeModule(self: *Self, comptime T: type, comptime field_name: []const u8, module: *T) !void {
    if (@hasField(T, field_name)) {

        // Init pool
        const type_index: TypeIndex = @intCast(self.types.items.len);
        @field(module, field_name) = try .init(self, module, type_index);

        // Create vtable
        const gen = struct {
            fn new(pointer: *anyopaque, parent: NodeID) !NodeID {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return (try @field(mod, field_name).new(parent)).id;
            }
            fn delete(pointer: *anyopaque, id: NodeID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return @field(mod, field_name).delete(id);
            }
            fn deinit(pointer: *anyopaque) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                @field(mod, field_name).deinit();
            }
            fn save(pointer: *anyopaque, writer: *Writer, id: NodeID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return @field(mod, field_name).save(writer, id);
            }
            fn load(pointer: *anyopaque, reader: *Reader, id: NodeID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return @field(mod, field_name).load(reader, id);
            }
        };

        // Register type
        (try self.types.addOne(self.allocator)).* = .{
            .name = @typeName(T),
            .v_ptr = module,
            .v_new = gen.new,
            .v_delete = gen.delete,
            .v_deinit = gen.deinit,
            .v_save = gen.save,
            .v_load = gen.load,
        };
    }
}

pub fn new(self: *Self, typename: []const u8, parent: NodeID) !NodeID {
    const typ = try self.findType(typename);
    return typ.v_new(typ.v_ptr, parent);
}
pub fn newEmpty(self: *Self, parent: NodeID) !NodeID {
    return (try self.empty_nodes.new(parent)).id;
}
pub fn delete(self: *Self, id: NodeID) !void {
    const typ = try self.getType(id);
    return typ.v_delete(typ.v_ptr, id);
}
pub fn valid(self: *Self, id: NodeID) bool {
    _ = self.getEntry(id) catch return false;
    return true;
}
pub fn getParent(self: *Self, id: NodeID) !NodeID {
    const node = try self.getEntry(id);
    if (node.parent != 0) {
        return .{
            .index = node.parent,
            .version = self.entries.items[node.parent].version,
        };
    }
    return .null;
}
pub fn getType(self: *Self, id: NodeID) !*NodeType {
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
fn dumpRecursive(self: *Self, index: EntryIndex, depth: u32) void {
    const node = self.entries.items[index];
    const typ = self.types.items[node.type_index];
    if (depth > 0) {
        for (0..depth - 1) |_| {
            std.debug.print(" ", .{});
        }
        if (node.next != 0) {
            std.debug.print("├─ ", .{});
        } else {
            std.debug.print("└─ ", .{});
        }
    }
    const id = NodeID{
        .index = index,
        .version = node.version,
    };
    std.debug.print("0x{x:0>8} ({s})\n", .{ @as(u32, @bitCast(id)), typ.name });

    var next = node.child;
    while (next != 0) {
        const child = self.entries.items[next];
        dumpRecursive(self, next, depth + 1);
        next = child.next;
    }
}
const Dumper = struct {
    node: *Self,
    depth: u32 = 0,
    header: [256]u8 = undefined,
    // header_len: usize = 0,
    fn onPreOrder(self: *@This(), id: NodeID) !void {
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
                0 => try w.print("├─", .{}),
                1 => try w.print("└─", .{}),
                2 => try w.print("│ ", .{}),
                3 => try w.print("  ", .{}),
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
        self.node.logger.info("{s}{d} {s}", .{ buf[0..w.end], @as(u32, @bitCast(id)), typ.name });
        self.depth += 1;
    }
    fn onPostOrder(self: *@This(), _: NodeID) !void {
        self.depth -= 1;
    }
};
pub fn dump(self: *Self, id: NodeID) void {
    var dumper = Dumper{ .node = self };
    self.visit(id, &dumper) catch {};
}

pub fn exportNode(self: *Self, id: NodeID, path: []const u8) !void {
    var buf: [256]u8 = undefined;
    var file_writer: nux.Disk.FileWriter = try .open(self.disk, path, &buf);
    defer file_writer.close();
    var writer: Writer = .{
        .node = self,
        .writer = &file_writer.interface,
    };
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
        const parent = try self.getParent(node);
        var parent_index: u32 = 0;
        for (nodes.items, 0..) |item, index| {
            if (item == parent) {
                parent_index = @intCast(index + 1);
                break;
            }
        }

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
    }
    // Write nodes data
    for (nodes.items) |node| {
        const typ = try self.getType(node);
        try typ.v_save(typ.v_ptr, &writer, node);
    }
}
pub fn importNode(self: *Self, parent: NodeID, path: []const u8) !NodeID {
    // Read entry
    const data = try self.disk.readEntry(path, self.allocator);
    defer self.allocator.free(data);
    var data_reader = std.Io.Reader.fixed(data);
    var reader: Reader = .{
        .reader = &data_reader,
        .node = self,
    };
    // Read type table
    const type_table_len = try reader.read(u32);
    if (type_table_len == 0) return error.emptyNodeFile;
    const type_table = try self.allocator.alloc([]const u8, type_table_len);
    defer self.allocator.free(type_table);
    for (0..type_table_len) |index| {
        type_table[index] = try reader.readString();
        _ = self.findType(type_table[index]) catch {
            return error.nodeTypeNotFound;
        };
    }
    // Read node table
    const node_count = try reader.read(u32);
    var nodes = try self.allocator.alloc(NodeID, node_count);
    defer self.allocator.free(nodes);
    for (0..node_count) |index| {
        const type_index = try reader.read(u32);
        const parent_index = try reader.read(u32);
        if (type_index > type_table_len) {
            return error.invalidTypeIndex;
        }
        if (parent_index > nodes.len + 1) {
            return error.invalidParentIndex;
        }
        const typ = try self.findType(type_table[type_index]);
        const parent_node = if (parent_index != 0) nodes[parent_index - 1] else parent;
        nodes[index] = try typ.v_new(typ.v_ptr, parent_node);
    }
    // Read node data
    for (nodes) |node| {
        const typ = try self.getType(node);
        try typ.v_load(typ.v_ptr, &reader, node);
    }
    return nodes[0];
}
