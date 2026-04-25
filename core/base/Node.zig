const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const Version = u8;
pub const NodeIndex = u24;

pub const max_name: usize = 64;
pub const max_component = 128;
pub const path_separator = '/';

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

const Entry = struct {
    version: Version = 1,
    parent: NodeIndex = 0,
    prev: NodeIndex = 0,
    next: NodeIndex = 0,
    first_child: NodeIndex = 0,
    last_child: NodeIndex = 0,
    name: [max_name]u8 = undefined,
    name_len: usize = 0,
    components: [max_component]?nux.Component.Index = .{null} ** max_component,
    instanceof: ID = .null,

    // TODO: use actived deactived for side effects (in editor)

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
                if (self.node.valid(v)) {
                    var found = false;
                    for (self.nodes, 0..) |id, index| {
                        if (v == id) {
                            try self.writer.writeByte(1); // Local path
                            try self.writer.writeInt(u32, @intCast(index), .little);
                            found = true;
                            break;
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
                            if (@field(v, F.name) == null) {
                                try self.writer.writeByte(0);
                            } else {
                                try self.writer.writeByte(1);
                            }
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
    allocator: std.mem.Allocator,

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
                            return error.InvalidLocalNodeIndex;
                        }
                        return self.nodes[local_index];
                    },
                    2 => {
                        const global_path = try self.read([]u8);
                        return try self.node.findGlobal(global_path);
                    },
                    else => {
                        return error.InvalidNodePathType;
                    },
                }
            },
            nux.Vec2, nux.Vec3, nux.Vec4 => {
                return .initArray(try self.read(@FieldType(T, "data")));
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
                .pointer => |info| switch (info.size) {
                    // .one => {
                    //     return self.write(v.*);
                    //     const slice = try allocator.alloc(info.child, size);
                    // },
                    .slice => {
                        const len = @as(usize, @intCast(try self.read(u32)));
                        if (info.child == u8) {
                            return try self.reader.readAlloc(self.allocator, len);
                        } else {
                            const buf = try self.allocator.alloc(info.child, len);
                            errdefer self.allocator.free(buf);
                            for (0..len) |index| {
                                buf[index] = try self.read(info.child);
                            }
                            return buf;
                        }
                    },
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

const ChildIterator = struct {
    self: *Self,
    current: NodeIndex,
    fn init(mod: *Self, id: ID) !@This() {
        return .{
            .self = mod,
            .current = (try mod.getEntry(id)).first_child,
        };
    }
    pub fn next(it: *@This()) ?ID {
        const index = it.current;
        if (index == 0) return null;
        const entry = it.self.entries.get(index);
        it.current = entry.next;
        return .{
            .index = index,
            .version = entry.version,
        };
    }
};

const ComponentIterator = struct {
    self: *Self,
    entry: *Entry,
    current: usize,
    fn init(mod: *Self, id: ID) !@This() {
        return .{
            .self = mod,
            .entry = (try mod.getEntry(id)),
            .current = 0,
        };
    }
    pub fn next(it: *@This()) ?nux.ModuleID {
        while (it.current < it.entry.components.len) {
            const index = it.current;
            it.current += 1;
            if (it.entry.components[index] != null) {
                return .{ .index = @intCast(index) };
            }
        }
        return null;
    }
};

pub fn iterChildren(self: *Self, id: ID) !ChildIterator {
    return try .init(self, id);
}
pub fn iterComponents(self: *Self, id: ID) !ComponentIterator {
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
    var nodes = try std.ArrayList(ID).initCapacity(allocator, 32);
    errdefer nodes.deinit(allocator);
    try self.collectInto(&nodes, allocator, id);
    return nodes;
}
pub fn collectInto(
    self: *Self,
    array_list: *std.ArrayList(ID),
    allocator: std.mem.Allocator,
    id: ID,
) !void {
    const Collector = struct {
        nodes: *std.ArrayList(ID),
        allocator: std.mem.Allocator,
        fn onPreOrder(collector: *@This(), node: ID) !void {
            try collector.nodes.append(collector.allocator, node);
        }
    };
    var collector = Collector{
        .allocator = allocator,
        .nodes = array_list,
    };
    try self.visit(id, &collector);
}

allocator: std.mem.Allocator,
entries: nux.ObjectPool(Entry),
root: ID,
component: *nux.Component,
file: *nux.File,
logger: *nux.Logger,
collection: *nux.Scene,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.entries = .init(self.allocator);
    // Reserve index 0 for null id.
    _ = try self.entries.add(.{});
    // Create root node manually.
    self.root = ID{
        .index = 1,
        .version = 1,
    };
    _ = try self.entries.add(.{
        .version = self.root.version,
    });
    try self.setName(self.root, "root");
}
pub fn deinit(self: *Self) void {
    self.entries.deinit();
}
pub fn onStop(self: *Self) void {
    self.delete(self.getRoot()) catch {};
}

fn addEntry(self: *Self, parent: ID) !ID {

    // Check parent
    if (!self.valid(parent)) {
        return error.InvalidParent;
    }

    // Find free entry
    const index: NodeIndex = @intCast(try self.entries.add(.{}));

    // Init node
    const node = self.entries.get(index);
    node.parent = parent.index;
    const id = ID{
        .index = index,
        .version = node.version,
    };

    // Update parent
    if (parent.index != 0) {
        const p = self.entries.get(parent.index);
        if (p.last_child != 0) {
            self.entries.get(p.last_child).next = index;
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
    var node = self.entries.get(id.index);
    // Remove from parent
    if (node.parent != 0) {
        const p = self.entries.get(node.parent);
        if (p.first_child == id.index) {
            p.first_child = node.next;
        }
        if (p.last_child == id.index) {
            p.last_child = node.prev;
        }
        if (node.next != 0) {
            self.entries.get(node.next).prev = node.prev;
        }
        if (node.prev != 0) {
            self.entries.get(node.prev).next = node.next;
        }
    }
    // Update version and add to freelist
    node.version += 1;
    self.entries.remove(id.index);
}
pub fn getEntry(self: *Self, id: ID) !*Entry {
    if (id.isNull()) {
        return error.NullId;
    }
    if (id.index >= self.entries.items.items.len) {
        return error.InvalidIndex;
    }
    const node = self.entries.get(id.index);
    if (node.version != id.version) {
        return error.InvalidVersion;
    }
    return node;
}

pub fn getRoot(self: *Self) ID {
    return self.root;
}

pub fn create(self: *Self, parent: ID) !ID {
    return self.addEntry(parent);
}
pub fn createNamed(self: *Self, parent: ID, name: []const u8) !ID {
    const id = try self.create(parent);
    try self.setName(id, name);
    return id;
}
pub fn createPath(self: *Self, base: ID, path: []const u8) !ID {
    var it = std.mem.splitScalar(u8, path, path_separator);
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
pub fn createInstanceOf(self: *Self, parent: ID, collection: ID) !ID {
    return self.collection.instantiate(collection, parent);
}
pub fn delete(self: *Self, id: ID) !void {

    // Delete children
    var it = try self.iterChildren(id);
    while (it.next()) |child| {
        try self.delete(child);
    }

    // Remove components
    var cit = try self.iterComponents(id);
    while (cit.next()) |cid| {
        const module = try self.component.getModule(cid);
        module.v_component.?.remove(module.v_ptr, id);
    }

    // Delete entry
    try self.removeEntry(id);
}
pub fn valid(self: *Self, id: ID) bool {
    _ = self.getEntry(id) catch return false;
    return true;
}
pub fn exists(self: *Self, path: []const u8) bool {
    _ = self.findGlobal(path) catch return false;
    return true;
}
pub fn getParent(self: *Self, id: ID) !ID {
    const node = try self.getEntry(id);
    if (node.parent != 0) {
        return .{
            .index = node.parent,
            .version = self.entries.get(node.parent).version,
        };
    }
    return error.NoParent;
}
pub fn find(self: *Self, relativeTo: ID, path: []const u8) !ID {
    const entry = try self.getEntry(relativeTo);
    _ = entry;
    var it = std.mem.splitScalar(u8, path, path_separator);
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
    var buf: [max_name]u8 = undefined;
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
fn writeEntryPath(self: *Self, entry: *Entry, writer: *std.Io.Writer) !void {
    if (entry.parent == 0) { // root node
        return;
    }
    try self.writeEntryPath(self.entries.get(entry.parent), writer);
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

        // Print components
        var it = try self.node.iterComponents(id);
        while (it.next()) |cid| {
            const typ = try self.node.component.get(cid);

            // Print header
            var buf: [256]u8 = undefined;
            var w = std.Io.Writer.fixed(&buf);
            try self.writeHeader(&w);

            // Write type
            try w.print("\x1b[31m", .{}); // red
            try w.print("{s} ", .{typ.name});

            // Write description
            try w.print("\x1b[90m", .{}); // light gray
            try typ.v_description(typ.v_ptr, id, &w);
            try w.print("\x1b[37m", .{}); // white

            self.node.logger.info("{s}", .{buf[0..w.end]});
        }
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
        // try self.printComponents(id);

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
