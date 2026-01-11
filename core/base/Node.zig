const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const NodeID = packed struct(u32) {
    pub const @"null" = @This(){ .version = 0, .index = 0 };

    pub fn isNull(self: *const @This()) bool {
        return self.index == 0;
    }
    pub fn setNull(self: *@This()) void {
        self.index = 0;
    }

    version: NodeEntry.Version,
    index: NodeEntry.Index,
};

const NodeEntry = struct {
    pub const Version = u8;
    pub const Index = u24;
    pub const PoolIndex = u32;
    pub const TypeIndex = u32;

    version: Version,
    pool_index: PoolIndex,
    type_index: TypeIndex,

    parent: NodeID,
    prev: NodeID,
    next: NodeID,
    child: NodeID,
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
        tree: *Tree,
        type_index: NodeEntry.TypeIndex,
        data: std.ArrayList(T),
        ids: std.ArrayList(NodeID),

        fn init(tree: *Tree, type_index: NodeEntry.TypeIndex) !@This() {
            return .{
                .allocator = tree.allocator,
                .type_index = type_index,
                .tree = tree,
                .data = try .initCapacity(tree.allocator, 1000),
                .ids = try .initCapacity(tree.allocator, 1000),
            };
        }
        fn deinit(self: *@This()) void {
            self.data.deinit(self.allocator);
            self.ids.deinit(self.allocator);
        }

        pub fn new(self: *@This(), parent: NodeID) !NodeID {
            const pool_index = self.data.items.len;
            const id = try self.tree.add(parent, @intCast(pool_index), self.type_index);
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
            const node = try self.tree.get(id);
            // deinit node
            if (@hasDecl(T, "deinit")) {
                T.deinit(@fieldParentPtr("nodes", self), &self.data.items[node.pool_index]);
            }
            // remove node from graph
            try self.tree.remove(id);
            // update last item before swap remove
            self.tree.updatePoolIndex(self.ids.items[node.pool_index], node.pool_index);
            // remove from array
            _ = self.data.swapRemove(node.pool_index);
            _ = self.ids.swapRemove(node.pool_index);
        }
        pub fn get(self: *@This(), id: NodeID) !*T {
            const node = try self.tree.get(id);
            return &self.data.items[node.pool_index];
        }
    };
}

const Tree = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(NodeEntry),
    free: std.ArrayList(NodeEntry.Index),

    fn init(allocator: std.mem.Allocator) !@This() {
        var tree: Tree = .{
            .allocator = allocator,
            .entries = try .initCapacity(allocator, 1024),
            .free = try .initCapacity(allocator, 1024),
        };
        // reserve index 0 for null id
        _ = try tree.entries.addOne(tree.allocator);
        return tree;
    }
    fn deinit(self: *Tree) void {
        self.entries.deinit(self.allocator);
        self.free.deinit(self.allocator);
    }

    fn add(self: *Tree, parent: NodeID, pool_index: NodeEntry.Index, type_index: NodeEntry.TypeIndex) !NodeID {
        var index: NodeEntry.Index = undefined;
        if (self.free.pop()) |idx| {
            index = idx;
        } else {
            index = @intCast(self.entries.items.len);
            const object = try self.entries.addOne(self.allocator);
            object.version = 0;
        }
        var node = &self.entries.items[index];
        node.pool_index = pool_index;
        node.type_index = type_index;
        node.parent = parent;
        node.child = .null;
        node.next = .null;
        node.prev = .null;
        return .{
            .index = index,
            .version = node.version,
        };
    }
    fn remove(self: *Tree, id: NodeID) !void {
        var node = &self.entries.items[id.index];
        node.version += 1;
        (try self.free.addOne(self.allocator)).* = id.index;
    }
    fn updatePoolIndex(self: *Tree, id: NodeID, pool_index: NodeEntry.PoolIndex) void {
        self.entries.items[id.index].pool_index = pool_index;
    }
    fn get(self: *Tree, id: NodeID) !*NodeEntry {
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
};

allocator: std.mem.Allocator,
types: std.ArrayList(NodeType),
tree: Tree,
root: NodeID,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.types = try .initCapacity(self.allocator, 64);
    self.tree = try .init(self.allocator);
}
pub fn deinit(self: *Self) void {
    self.tree.deinit();
    for (self.types.items) |typ| {
        typ.v_deinit(typ.v_ptr);
    }
    self.types.deinit(self.allocator);
}

pub fn registerNodePool(self: *Self, comptime T: type, module: *T) !void {
    if (@hasField(T, "nodes")) {

        // init pool
        const type_index: NodeEntry.TypeIndex = @intCast(self.types.items.len);
        module.nodes = try .init(&self.tree, type_index);

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
                mod.nodes.deinit();
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

pub fn new(self: *Self, typename: []const u8, parent: NodeID) !NodeID {
    const typ = try self.findType(typename);
    return typ.v_new(typ.v_ptr, parent);
}
pub fn delete(self: *Self, id: NodeID) !void {
    const typ = try self.getType(id);
    return typ.v_delete(typ.v_ptr, id);
}
pub fn getParent(self: *Self, id: NodeID) !NodeID {
    const node = try self.tree.get(id);
    return node.parent;
}
pub fn setParent(self: *Self, id: NodeID, parent: NodeID) !void {
    _ = parent;
    const node = try self.tree.get(id);
    _ = node;
}
pub fn getType(self: *Self, id: NodeID) !*NodeType {
    const node = try self.tree.get(id);
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
    const node = self.tree.get(id) catch return;
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
        const cinfo = self.tree.get(id) catch break;
        dumpRecursive(self, next, depth + 1);
        next = cinfo.next;
    }
}
pub fn dump(self: *Self, id: NodeID) void {
    dumpRecursive(self, id, 0);
}
