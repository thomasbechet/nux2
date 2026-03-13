const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Node = struct {
    parent: ?usize, // null if root node
    name_start: usize,
    name_end: usize,
    component_indices_start: usize,
    component_indices_end: usize,
    component_data_start: usize,
    component_data_end: usize,
};
const Collection = struct {
    path: []const u8,
    nodes: std.ArrayList(Node),
    references: std.ArrayList([]const u8),
    component_ids: std.ArrayList(nux.Component.ID),
    component_indices: std.ArrayList(usize),
    data: std.ArrayList(u8),

    fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.nodes.deinit(allocator);
        self.references.deinit(allocator);
        self.component_ids.deinit(allocator);
        self.component_indices.deinit(allocator);
        self.data.deinit(allocator);
    }
};

allocator: std.mem.Allocator,
collections: std.StringHashMap(Collection),
node: *nux.Node,
file: *nux.File,
component: *nux.Component,
ids: std.ArrayList(nux.ID), // Temporary id pool for node_index <> id mapping

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.collections = .init(self.allocator);
    self.ids = .empty;
}
pub fn deinit(self: *Self) void {
    self.ids.deinit(self.allocator);
    var it = self.collections.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key_ptr.*);
        entry.value_ptr.deinit(self.allocator);
    }
    self.collections.deinit();
}

fn getCollection(self: *Self, path: []const u8) !*Collection {
    const found = try self.collections.getOrPut(path);
    if (!found.found_existing) {
        found.key_ptr = try self.allocator.dupe(u8, path);
    }
    return found.value_ptr;
}

pub fn exportNode(self: *Self, path: []const u8, id: nux.ID) !Collection {

    // Collect nodes
    self.ids.items.len = 0;
    try self.node.collectInto(&self.ids, self.allocator, id);

    // Allocate resources
    var entries: std.ArrayList(Node) = try .initCapacity(self.allocator, self.ids.items.len);
    errdefer entries.deinit(self.allocator);
    var component_ids: std.ArrayList(nux.Component.ID) = try .initCapacity(self.allocator, 256);
    errdefer component_ids.deinit(self.allocator);

    var component_indices: std.ArrayList(usize) = try .initCapacity(self.allocator, 256);
    errdefer component_indices.deinit(self.allocator);
    var data: std.ArrayList(u8) = try .initCapacity(self.allocator, 256);
    errdefer data.deinit(self.allocator);

    // Collect entries and components
    for (self.ids.items, 0..) |node, node_index| {
        const name = try self.node.getName(node);

        // Create entry
        var entry = try entries.addOne(self.allocator);

        // Append name
        entry.name_start = data.items.len;
        try data.appendSlice(self.allocator, name);
        entry.name_end = data.items.len;

        // Find parent index
        entry.parent = null;
        if (node_index != 0) {
            const node_parent = try self.node.getParent(node);
            for (self.ids.items, 0..) |parent, parent_index| {
                if (parent == node_parent) {
                    entry.parent = parent_index;
                    break;
                }
            }
            unreachable;
        }

        // Collect components
        var it = try self.node.iterComponents(node);
        entry.component_indices_start = component_indices.items.len;
        while (it.next()) |cid| {

            // Find component index from component ids
            var component_index: ?usize = null;
            for (component_ids.items, 0..) |component_id, index| {
                if (component_id == cid) {
                    component_index = index;
                    break;
                }
            }

            // Component not found, append id to list
            if (component_index == null) {
                component_index = component_ids.items.len;
                try component_ids.append(self.allocator, cid);
            }

            // Append component index
            try component_indices.append(self.allocator, component_index.?);
        }
        entry.component_indices_end = component_indices.items.len;
    }

    // Prepare data writer
    var data_writer = std.Io.Writer.Allocating.init(self.allocator);
    var writer = nux.Writer{
        .writer = &data_writer.writer,
        .node = self.node,
        .nodes = self.ids.items,
    };

    // Collect components data
    for (self.ids.items, 0..) |node, index| {

        // Collect components
        entries.items[index].component_data_start = data.items.len;
        var it = try self.node.iterComponents(node);
        while (it.next()) |cid| {
            const typ = try self.component.get(cid);
            try typ.v_save(typ.v_ptr, node, &writer);
        }
        entries.items[index].component_data_end = data.items.len;
    }

    return .{
        .path = path,
        .component_ids = component_ids,
        .component_indices = component_indices,
        .data = data_writer.toArrayList(),
        .nodes = entries,
        .references = undefined,
    };
}
// pub fn load(self: *Self, path: []const u8) !void {}
// pub fn save(self: *Self, path: []const u8) !void {
//
//     // Open file
//     var buf: [512]u8 = undefined;
//     var file_writer: nux.File.Writer = try .open(self.file, path, &buf);
//     defer file_writer.close();
// }
pub fn instantiate(self: *Self, path: []const u8, parent: nux.ID) !nux.ID {
    const collection = self.collections.get(path) orelse return error.CollectionNotFound;

    // Create nodes
    try self.ids.resize(self.allocator, collection.nodes.items.len);
    for (collection.nodes.items, 0..) |*entry, index| {
        const node_parent = if (entry.parent) |parent_index| {
            return self.ids.items[parent_index];
        } else {
            return parent;
        };
        if (entry.name) |name| {
            self.ids.items[index] = try self.node.createNamed(node_parent, name);
        } else {
            self.ids.items[index] = try self.node.create(node_parent);
        }
    }

    // Create components
    for (collection.nodes.items, 0..) |*entry, index| {
        const id = self.ids.items[index];
        var data_reader = std.Io.Reader.fixed(collection.data.items[entry.component_data_start..entry.component_data_end]);
        var reader = nux.Node.Reader{
            .reader = &data_reader,
            .node = self.node,
            .nodes = self.ids.items,
        };
        for (collection.component_indices.items[entry.component_indices_start..entry.component_indices_end]) |component_index| {
            const component_id = collection.component_ids.items[component_index];
            const typ = try self.component.get(component_id);
            try typ.v_load(typ.v_ptr, id, &reader);
        }
    }

    // Return root
    return self.ids.items[0];
}
// pub fn exportNode(self: *Self, id: nux.ID, path: []const u8) !void {
//     var buf: [512]u8 = undefined;
//     var file_writer: nux.File.Writer = try .open(self.file, path, &buf);
//     defer file_writer.close();
//     // Collect nodes
//     var nodes = try self.collect(self.allocator, id);
//     defer nodes.deinit(self.allocator);
//     // Collect components
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
//     var writer: nux.Node.Writer = .{
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
