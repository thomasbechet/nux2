const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Node = struct {
    source_file: nux.NodeID = .null,
    lua_module: nux.Lua.LuaModule = .{},
};

lua: *nux.Lua,
source_file: *nux.SourceFile,
logger: *nux.Logger,
nodes: nux.NodePool(Node),

pub fn new(self: *Self, parent: nux.NodeID) !nux.NodeID {
    return try self.nodes.new(parent, .{});
}
pub fn delete(self: *Self, id: nux.NodeID) !void {
    const data = try self.nodes.get(id);
    try self.lua.callModule(&data.lua_module, "onUnload", 0);
    try self.lua.unloadModule(&data.lua_module);
}
pub fn newFromSourceFile(self: *Self, parent: nux.NodeID, source_file: nux.NodeID) !nux.NodeID {
    const id = try self.new(parent);
    try self.setSourceFile(id, source_file);
    return id;
}
pub fn setSourceFile(self: *Self, id: nux.NodeID, source_file: nux.NodeID) !void {
    const data = try self.nodes.get(id);
    const source = try self.source_file.getSource(source_file);
    data.source_file = source_file;
    // TODO check is lua or wren file
    try self.lua.loadModule(&data.lua_module, id, "myscript", source);
    try self.lua.callModule(&data.lua_module, "onLoad", 0);
}
