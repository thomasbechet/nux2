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
    pub fn write(writer: *Writer, v: anytype) !void {
        _ = writer;
        switch (@typeInfo(@TypeOf(v))) {
            .int => {},
            .float => {},
            .array => |array| {
                _ = array;
                // TODO
            },
            .@"struct" => {},
            else => @compileError("unsupported type"),
        }
    }
};

pub const NodeType = struct {
    name: []const u8,
    v_ptr: *anyopaque,
    v_new: *const fn (*anyopaque, parent: NodeID) anyerror!NodeID,
    v_delete: *const fn (*anyopaque, id: NodeID) anyerror!void,
    v_deinit: *const fn (*anyopaque) void,
    v_save: *const fn (*anyopaque, id: NodeID) anyerror!void,
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
            // add entry
            const pool_index = self.data.items.len;
            const id = try self.node.addEntry(parent, @intCast(pool_index), self.type_index);
            // add data entry
            const data_ptr = try self.data.addOne(self.allocator);
            const id_ptr = try self.ids.addOne(self.allocator);
            id_ptr.* = id;
            // init node
            if (@hasDecl(T, "init")) {
                data_ptr.* = try T.init(@ptrCast(@alignCast(self.mod)));
            }
            return .{ .id = id, .data = data_ptr };
        }
        fn delete(self: *@This(), id: NodeID) !void {
            const node = try self.node.getEntry(id);
            // delete children
            var it = node.child;
            while (it != 0) {
                const child = &self.node.entries.items[it];
                try self.node.delete(.{
                    .version = child.version,
                    .index = it,
                });
                it = child.next;
            }
            // deinit node
            if (@hasDecl(T, "deinit")) {
                T.deinit(@ptrCast(@alignCast(self.mod)), &self.data.items[node.pool_index]);
            }
            // remove node from graph
            try self.node.removeEntry(id);
            // update last item before swap remove
            self.node.updateEntry(self.ids.items[node.pool_index], node.pool_index);
            // remove from pool
            _ = self.data.swapRemove(node.pool_index);
            _ = self.ids.swapRemove(node.pool_index);
        }
        pub fn get(self: *@This(), id: NodeID) !*T {
            const node = try self.node.getEntry(id);
            return &self.data.items[node.pool_index];
        }
        pub fn save(self: *@This(), id: NodeID) !void {
            const node = try self.node.getEntry(id);
            var writer = Writer{};
            if (@hasDecl(T, "save")) {
                try T.save(@ptrCast(@alignCast(self.mod)), &writer, &self.data.items[node.pool_index]);
            }
        }
    };
}

fn Iterator(S: comptime_int) type {
    return struct {
        node: *Self,
        current: u32,
        stack: [S]u32,
        size: u32,

        fn init(self: *Self) @This() {
            return .{
                .node = self,
                .current = 0,
                .size = 0,
            };
        }
        fn next(it: *@This()) ?NodeID {
            while (it.size > 0) {
                // pop stack
                it.size -= 1;
                const idx = it.stack[it.size];
                // get current node
                const cur = it.node.entries.items[idx];
                // push childs
                var child = cur.child;
                while (!child.isNull()) {
                    it.stack[it.size] = child.index;
                    it.size += 1;
                    child = it.node.entries.items[child.index].next;
                }
                return idx;
            }
            return null;
        }
    };
}

allocator: std.mem.Allocator,
types: std.ArrayList(NodeType),
entries: std.ArrayList(NodeEntry),
free: std.ArrayList(EntryIndex),
empty_nodes: NodePool(struct { dummy: u32 }),
root: NodeID,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.types = try .initCapacity(self.allocator, 64);
    self.entries = try .initCapacity(self.allocator, 1024);
    self.free = try .initCapacity(self.allocator, 1024);
    // reserve index 0 for null id
    try self.entries.append(self.allocator, .{});
    // register empty node type
    try self.registerNodeModule(Self, "empty_nodes", self);
    // create root node
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
    // check parent
    if (!self.valid(parent)) {
        return error.invalidParent;
    }

    // find free entry
    var index: EntryIndex = undefined;
    if (self.free.pop()) |idx| {
        index = idx;
    } else {
        index = @intCast(self.entries.items.len);
        const node = try self.entries.addOne(self.allocator);
        node.version = 0;
    }

    // initialize node
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

    // update parent
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
    // update version and add to freelist
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
pub fn deleteAll(self: *Self) void {
    var it = self.root.index;
    while (it != 0) {
        const child = &self.entries.items[it];
        self.delete(.{
            .version = child.version,
            .index = it,
        }) catch {};
        it = child.next;
    }
}
pub fn registerNodeModule(self: *Self, comptime T: type, comptime field_name: []const u8, module: *T) !void {
    if (@hasField(T, field_name)) {

        // init pool
        const type_index: TypeIndex = @intCast(self.types.items.len);
        @field(module, field_name) = try .init(self, module, type_index);

        // create vtable
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
            fn save(pointer: *anyopaque, id: NodeID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return @field(mod, field_name).save(id);
            }
        };

        // register type
        (try self.types.addOne(self.allocator)).* = .{
            .name = @typeName(T),
            .v_ptr = module,
            .v_new = gen.new,
            .v_delete = gen.delete,
            .v_deinit = gen.deinit,
            .v_save = gen.save,
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
pub fn save(self: *Self, id: NodeID) !void {
    const typ = try self.getType(id);
    return typ.v_save(typ.v_ptr, id);
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
pub fn dump(self: *Self, id: NodeID) void {
    if (self.valid(id)) {
        dumpRecursive(self, id.index, 0);
    }
}
