const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Node = struct {
    parent: ?usize, // null if root node
    name_start: usize,
    name_end: usize,
    module_indices_start: usize,
    module_indices_end: usize,
    component_data_start: usize,
    component_data_end: usize,
};
const Collection = struct {
    path: []const u8 = "",
    nodes: std.ArrayList(Node) = .empty,
    references: std.ArrayList([]const u8) = .empty,
    module_ids: std.ArrayList(nux.ModuleID) = .empty,
    module_indices: std.ArrayList(usize) = .empty,
    data: std.ArrayList(u8) = .empty,

    pub fn deinit(self: *Collection, mod: *Self) void {
        self.nodes.deinit(mod.allocator);
        self.references.deinit(mod.allocator);
        self.module_ids.deinit(mod.allocator);
        self.module_indices.deinit(mod.allocator);
        self.data.deinit(mod.allocator);
    }
};

allocator: std.mem.Allocator,
components: nux.Components(Collection),
node: *nux.Node,
file: *nux.File,
module: *nux.Module,
ids: std.ArrayList(nux.ID), // Temporary id pool for node_index <> id mapping

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.ids = .empty;
}
pub fn deinit(self: *Self) void {
    self.ids.deinit(self.allocator);
}

pub fn exportNode(self: *Self, parent: nux.ID, root: nux.ID) !nux.ID {

    // Collect nodes
    self.ids.items.len = 0;
    try self.node.collectInto(&self.ids, self.allocator, root);

    // Allocate resources
    var entries: std.ArrayList(Node) = try .initCapacity(self.allocator, self.ids.items.len);
    errdefer entries.deinit(self.allocator);

    var module_ids: std.ArrayList(nux.ComponentID) = try .initCapacity(self.allocator, 256);
    errdefer module_ids.deinit(self.allocator);

    var module_indices: std.ArrayList(usize) = try .initCapacity(self.allocator, 256);
    errdefer module_indices.deinit(self.allocator);

    var data: std.ArrayList(u8) = try .initCapacity(self.allocator, 256);
    errdefer data.deinit(self.allocator);

    // Collect entries and components
    for (self.ids.items, 0..) |node_id, node_index| {
        const name = try self.node.getName(node_id);

        // Create entry
        var node = try entries.addOne(self.allocator);

        // Append name
        node.name_start = data.items.len;
        try data.appendSlice(self.allocator, name);
        node.name_end = data.items.len;

        // Find parent index
        node.parent = null;
        if (node_index != 0) {
            const node_parent_id = try self.node.getParent(node_id);
            for (self.ids.items, 0..) |parent_id, parent_index| {
                if (parent_id == node_parent_id) {
                    node.parent = parent_index;
                    break;
                }
            }
            std.debug.assert(node.parent != null);
        }

        // Collect components
        var it = try self.node.iterComponents(node_id);
        node.module_indices_start = module_indices.items.len;
        while (it.next()) |cid| {

            // Find component index from component ids
            var component_index: ?usize = null;
            for (module_ids.items, 0..) |component_id, index| {
                if (component_id == cid) {
                    component_index = index;
                    break;
                }
            }

            // Component not found, append id to list
            if (component_index == null) {
                component_index = module_ids.items.len;
                try module_ids.append(self.allocator, cid);
            }

            // Append component index
            try module_indices.append(self.allocator, component_index.?);
        }
        node.module_indices_end = module_indices.items.len;
    }

    // Prepare data writer
    var data_writer = std.Io.Writer.Allocating.fromArrayList(self.allocator, &data);
    var writer = nux.Writer{
        .writer = &data_writer.writer,
        .node = self.node,
        .nodes = self.ids.items,
    };

    // Collect components data
    for (self.ids.items, 0..) |node, index| {

        // Collect components
        entries.items[index].component_data_start = data_writer.writer.end;
        var it = try self.node.iterComponents(node);
        while (it.next()) |cid| {
            const typ = try self.component.get(cid);
            try typ.v_save(typ.v_ptr, node, &writer);
        }
        entries.items[index].component_data_end = data_writer.writer.end;
    }

    const id = try self.node.create(parent);
    try self.components.addWith(id, .{
        .path = undefined,
        .module_ids = module_ids,
        .module_indices = module_indices,
        .data = data_writer.toArrayList(),
        .nodes = entries,
        .references = undefined,
    });
    return id;
}
pub fn instantiate(self: *Self, id: nux.ID, parent: nux.ID) !nux.ID {
    const collection = try self.components.get(id);

    // Create nodes
    try self.ids.resize(self.allocator, collection.nodes.items.len);
    for (collection.nodes.items, 0..) |*node, index| {
        const node_parent = if (node.parent) |parent_index|
            self.ids.items[parent_index]
        else
            parent;
        const name = collection.data.items[node.name_start..node.name_end];
        self.ids.items[index] = try self.node.createNamed(node_parent, name);
    }

    // Create components
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var reader = nux.Node.Reader{
        .reader = undefined,
        .node = self.node,
        .nodes = self.ids.items,
        .allocator = arena.allocator(),
    };
    for (collection.nodes.items, 0..) |*node, index| {
        // Create reader on component data
        const data = collection.data.items[node.component_data_start..node.component_data_end];
        var data_reader = std.Io.Reader.fixed(data);
        reader.reader = &data_reader;
        // Load components
        const node_id = self.ids.items[index];
        for (collection.module_indices.items[node.module_indices_start..node.module_indices_end]) |module_index| {
            // Clear arena
            _ = arena.reset(.retain_capacity);
            // Load component
            const module_id = collection.module_ids.items[module_index];
            const typ = try self.module.get(module_id);
            try typ.v_load(typ.v_ptr, node_id, &reader);
        }
    }

    // Return root
    return self.ids.items[0];
}
