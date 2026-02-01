const std = @import("std");
const nux = @import("../nux.zig");

const Module = @This();
const Node = struct {
    source_file: nux.NodeID = .null,
    lua_module: nux.Lua.LuaModule = .{},

    pub fn init(_: *Module) !@This() {
        return .{};
    }
    pub fn deinit(self: *@This(), mod: *Module) void {
        mod.lua.callModule(&self.lua_module, "onUnload", 0) catch {};
        mod.lua.unloadModule(&self.lua_module) catch {};
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
    try self.lua.loadModule(&node.data.lua_module, node.id, "myscript", source);
    try self.lua.callModule(&node.data.lua_module, "onLoad", 0);
    return node.id;
}
// pub fn reload(self: *Module, id: nux.NodeID) !void {}
