const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const Version = u8;
pub const EntryIndex = u24;
pub const PoolIndex = u32;
pub const TypeIndex = u32;

pub const NodeID = packed struct(u32) {
    pub const @"null" = @This(){ .version = 0, .index = 0 };
    pub const root = @This(){ .version = 1, .index = 1 };

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

    parent: NodeID = .null,
    prev: NodeID = .null,
    next: NodeID = .null,
    child: NodeID = .null,
};

pub const NodeType = struct {
    name: []const u8,
    v_ptr: *anyopaque,
    v_new: *const fn (*anyopaque, parent: NodeID) anyerror!NodeID,
    v_delete: *const fn (*anyopaque, id: NodeID) anyerror!void,
    v_deinit: *const fn (*anyopaque) void,
};

pub fn NodePool(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        node: *Self,
        type_index: TypeIndex,
        data: std.ArrayList(T),
        ids: std.ArrayList(NodeID),

        pub fn new(self: *@This(), parent: NodeID) !NodeID {
            const pool_index = self.data.items.len;
            const id = try self.node.addEntry(parent, @intCast(pool_index), self.type_index);
            const data_ptr = try self.data.addOne(self.allocator);
            const id_ptr = try self.ids.addOne(self.allocator);
            id_ptr.* = id;
            // init node
            if (@hasDecl(T, "init")) {
                data_ptr.* = try T.init(@fieldParentPtr("nodes", self));
            }
            return id;
        }
        fn delete(self: *@This(), id: NodeID) !void {
            const node = try self.node.getEntry(id);
            // deinit node
            if (@hasDecl(T, "deinit")) {
                T.deinit(@fieldParentPtr("nodes", self), &self.data.items[node.pool_index]);
            }
            // remove node from graph
            try self.node.removeEntry(id);
            // update last item before swap remove
            self.node.updateEntry(self.ids.items[node.pool_index], node.pool_index);
            // remove from pool
            _ = self.data.swapRemove(node.pool_index);
            _ = self.ids.swapRemove(node.pool_index);
            // delete children
            var it = node.child;
            while (!it.isNull()) {
                const cinfo = self.node.getEntry(it) catch break;
                try self.node.delete(it);
                it = cinfo.next;
            }
        }
        pub fn get(self: *@This(), id: NodeID) !*T {
            const node = try self.node.getEntry(id);
            return &self.data.items[node.pool_index];
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
empty_nodes: NodePool(struct { dummy: u32 }), // empty nodes

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.types = try .initCapacity(self.allocator, 64);
    self.entries = try .initCapacity(self.allocator, 1024);
    self.free = try .initCapacity(self.allocator, 1024);
    // reserve index 0 for null id
    try self.entries.append(self.allocator, .{});
    // create empty node type
    // try self.registerNodePool(@This(), self);
    // self.types.append(self.allocator, .{
    //     .name
    // })
    // self.empty_nodes = try .init(self, 0);
    // create root node as empty node
    _ = try self.empty_nodes.data.addOne(self.allocator);
    try self.entries.append(self.allocator, .{
        .version = NodeID.root.version,
        .pool_index = NodeID.root.index,
        .type_index = 0,
    });
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
        .parent = parent,
    };
    const id = NodeID{
        .index = index,
        .version = node.version,
    };

    // update parent
    if (!parent.isNull()) {
        const p = try self.getEntry(parent);
        p.child = id;
    }

    return id;
}
fn removeEntry(self: *Self, id: NodeID) !void {
    var node = &self.entries.items[id.index];
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

pub fn registerNodeModule(self: *Self, comptime T: type, module: *T) !void {
    if (@hasField(T, "nodes")) {

        // init pool
        const type_index: TypeIndex = @intCast(self.types.items.len);
        module.nodes = .{
            .allocator = self.allocator,
            .type_index = type_index,
            .node = self,
            .data = try .initCapacity(self.allocator, 1000),
            .ids = try .initCapacity(self.allocator, 1000),
        };

        // create vtable
        const gen = struct {
            fn new(pointer: *anyopaque, parent: NodeID) !NodeID {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return mod.nodes.new(parent);
            }
            fn delete(pointer: *anyopaque, id: NodeID) !void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                return mod.nodes.delete(id);
            }
            fn deinit(pointer: *anyopaque) void {
                const mod: *T = @ptrCast(@alignCast(pointer));
                mod.nodes.data.deinit(mod.nodes.allocator);
                mod.nodes.ids.deinit(mod.nodes.allocator);
            }
        };

        // register type
        (try self.types.addOne(self.allocator)).* = .{
            .name = @typeName(T),
            .v_ptr = module,
            .v_new = gen.new,
            .v_delete = gen.delete,
            .v_deinit = gen.deinit,
        };
    }
}

pub fn root() NodeID {
    return .root;
}
pub fn new(self: *Self, typename: []const u8, parent: NodeID) !NodeID {
    const typ = try self.findType(typename);
    return typ.v_new(typ.v_ptr, parent);
}
pub fn delete(self: *Self, id: NodeID) !void {
    if (id == NodeID.root) {
        return error.deleteRootNode;
    }
    const typ = try self.getType(id);
    return typ.v_delete(typ.v_ptr, id);
}
pub fn valid(self: *Self, id: NodeID) bool {
    _ = self.getEntry(id) catch return false;
    return true;
}
pub fn getParent(self: *Self, id: NodeID) !NodeID {
    return (try self.getEntry(id)).parent;
}
pub fn setParent(self: *Self, id: NodeID, parent: NodeID) !void {
    const node = try self.getEntry(id);
    node.parent = parent;
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
fn dumpRecursive(self: *Self, id: NodeID, depth: u32) void {
    const node = self.getEntry(id) catch return;
    const typ = self.getType(id) catch unreachable;
    for (0..depth) |_| {
        std.debug.print(" ", .{});
    }
    if (depth > 0) {
        std.debug.print("\\_ ", .{});
    }
    std.debug.print("0x{x:0>8} ({s})\n", .{ @as(u32, @bitCast(id)), typ.name });

    var next = node.child;
    while (!next.isNull()) {
        const cinfo = self.getEntry(id) catch break;
        dumpRecursive(self, next, depth + 1);
        next = cinfo.next;
    }
}
pub fn dump(self: *Self, id: NodeID) void {
    dumpRecursive(self, id, 0);
}
