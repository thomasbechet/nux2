const std = @import("std");
const nux = @import("../nux.zig");

const Module = @This();
const Node = struct {
    source_file: nux.NodeID = .null,
    lua_module: nux.Lua.LuaModule = .{},

    pub fn init(_: *Module) !@This() {
        return .{};
    }
};

lua: *nux.Lua,
source_file: *nux.SourceFile,
logger: *nux.Logger,
nodes: nux.NodePool(Node),

pub fn new(self: *Module, parent: nux.NodeID, source_file: nux.NodeID) !nux.NodeID {
    var node = try self.nodes.new(parent);
    const source = try self.source_file.getSource(source_file);
    node.data.source_file = source_file;
    // TODO check is lua or wren file
    node.data.lua_module = try self.lua.loadModule(null, node.id, source);
    return node.id;
}
