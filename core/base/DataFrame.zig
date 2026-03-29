const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

// pub const Component = struct {
//     pub const Column = union(nux.Property.Primitive) {
//         int: std.ArrayList(i64),
//         float: std.ArrayList(f64),
//         bool: std.ArrayList(bool),
//         string: std.ArrayList([]const u8),
//     };

//     props: std.ArrayList(nux.Property.Type) = .empty,
//     columns: std.ArrayList(Column) = .empty,
//     index: std.StringHashMap(usize),
//     row_count: usize = 0,

//     pub fn init(self: *Self) Component {
//         return .{
//             .index = .init(self.allocator),
//         };
//     }

//     pub fn deinit(self: *Component, mod: *Self) void {
//         for (self.columns.items) |*col| {
//             switch (col.data) {
//                 .int => |*a| a.deinit(mod.allocator),
//                 .float => |*a| a.deinit(mod.allocator),
//                 .bool => |*a| a.deinit(mod.allocator),
//                 .string => |*a| a.deinit(mod.allocator),
//             }
//         }
//         self.columns.deinit();
//     }

//     pub fn properties(self: *const Component) []const nux.Property.Type {
//         return self.props.items;
//     }

//     pub fn addColumn(
//         self: *Component,
//         name: []const u8,
//         primitive: nux.Property.Primitive,
//     ) !void {
//         var col = Column{
//             .data = switch (primitive) {
//                 .int => Column{ .int = std.ArrayList(i64).init(self.allocator) },
//                 .float => Column{ .float = std.ArrayList(f64).init(self.allocator) },
//                 .bool => Column{ .bool = std.ArrayList(bool).init(self.allocator) },
//                 .string => Column{ .string = std.ArrayList([]const u8).init(self.allocator) },
//             },
//         };

//         // Fill existing rows with default values
//         for (0..self.row_count) |_| {
//             try self.appendDefault(&col);
//         }

//         try self.columns.append(col);
//     }

//     fn appendDefault(self: *Component, col: *Column) !void {
//         switch (col.data) {
//             .int => |*a| try a.append(0),
//             .float => |*a| try a.append(0.0),
//             .bool => |*a| try a.append(false),
//             .string => |*a| try a.append(""),
//         }
//     }

//     pub fn appendRow(self: *DataFrame) !usize {
//         for (self.columns.items) |*col| {
//             try self.appendDefault(col);
//         }
//         self.row_count += 1;
//         return self.row_count - 1;
//     }

//     fn findColumn(self: *DataFrame, name: []const u8) ?*Column {
//         for (self.columns.items) |*col| {
//             if (std.mem.eql(u8, col.name, name)) return col;
//         }
//         return null;
//     }

//     pub fn setInt(
//         self: *DataFrame,
//         col_name: []const u8,
//         row: usize,
//         value: i64,
//     ) !void {
//         const col = self.findColumn(col_name) orelse return error.ColumnNotFound;

//         switch (col.data) {
//             .int => |*a| a.items[row] = value,
//             else => return error.TypeMismatch,
//         }
//     }

//     pub fn getInt(
//         self: *DataFrame,
//         col_name: []const u8,
//         row: usize,
//     ) !i64 {
//         const col = self.findColumn(col_name) orelse return error.ColumnNotFound;

//         return switch (col.data) {
//             .int => |*a| a.items[row],
//             else => error.TypeMismatch,
//         };
//     }
// };

// components: nux.Components(Component),
// allocator: nux.Platform.Allocator,
// node: *nux.Node,

// pub fn init(self: *Self, core: *const nux.Core) !void {
//     self.allocator = core.platform.allocator;
// }
