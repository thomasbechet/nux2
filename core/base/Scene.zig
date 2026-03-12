const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Node = nux.Node;

const Entry = struct {
    parent: ?usize, // null if root node
    name: ?[]const u8,
    components: []const nux.Node.ComponentID,
    data: []const u8,
};
const Scene = struct {
    entries: std.ArrayList(Entry),
    references: std.ArrayList([]const u8),
    components: std.ArrayList(Node.ComponentID),
    data: []const u8,
};

allocator: std.mem.Allocator,
scenes: std.StringHashMap(Scene),
node: *nux.Node,
ids: std.ArrayList(nux.ID), // Temporary id pool for entry_index => id

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.scenes = .init(self.allocator);
    self.ids = .empty;
}
pub fn deinit(self: *Self) void {
    self.ids.deinit(self.allocator);
    self.scenes.deinit();
}

// pub fn preload(self: *Self, path: []const u8) !void {
//
// }
pub fn instantiate(self: *Self, path: []const u8, parent: nux.ID) !nux.ID {
    const scene = self.scenes.get(path) orelse return error.SceneNotFound;
    // Create nodes
    try self.ids.resize(self.allocator, scene.entries.items.len);
    for (scene.entries.items, 0..) |*entry, index| {
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
    for (scene.entries.items, 0..) |*entry, index| {
        const id = self.ids.items[index];
        var data_reader = std.Io.Reader.fixed(entry.data);
        var reader = nux.Node.Reader{
            .reader = &data_reader,
            .node = self.node,
            .nodes = self.ids.items,
        };
        for (entry.components) |component_id| {
            const typ = try self.node.getComponentType(component_id);
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
