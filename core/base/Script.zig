const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Node = struct {
    source_file: nux.ID = .null,
    lua_table: nux.Lua.Table = .{},
};

lua: *nux.Lua,
source_file: *nux.SourceFile,
logger: *nux.Logger,
nodes: nux.NodePool(Node),

// pub fn new(self: *Self, parent: nux.ID) !nux.ID {
//     return try self.nodes.new(parent, .{});
// }
// pub fn delete(self: *Self, id: nux.ID) !void {
//     const data = try self.nodes.get(id);
//     try self.lua.callModule(&data.lua_module, "onUnload", 0);
//     try self.lua.deinitModule(&data.lua_module);
// }
// pub fn newFromSourceFile(self: *Self, parent: nux.ID, source_file: nux.ID) !nux.ID {
//     const id = try self.new(parent);
//     try self.setSourceFile(id, source_file);
//     return id;
// }
// pub fn setSourceFile(self: *Self, id: nux.ID, source_file: nux.ID) !void {
//     const data = try self.nodes.get(id);
//     const source = try self.source_file.getSource(source_file);
//     data.source_file = source_file;
//     // TODO check is lua or wren file
//     try self.lua.initModule(&data.lua_module, id, "myscript", source);
//     try self.lua.callModule(&data.lua_module, "onLoad", 0);
// }
