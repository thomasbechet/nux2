const std = @import("std");
const nux = @import("../nux.zig");

const Module = @This();
const Node = struct {
    parent: nux.NodeID = .null,
    position: nux.Vec3 = .zero(),
    scale: nux.Vec3 = .scalar(1),
    rotation: nux.Quat = .identity(),
    pub fn init(_: *Module) !@This() {
        return .{};
    }
    pub fn deinit(_: *@This(), _: *Module) void {}
    pub fn save(self: *@This(), _: *Module, writer: *nux.Writer) !void {
        try writer.write(self.*);
    }
    pub fn load(self: *@This(), _: *Module, reader: *nux.Reader) !void {
        self.* = try reader.read(@This());
    }
};

nodes: nux.NodePool(Node),
node: *nux.Node,
logger: *nux.Logger,

pub fn new(self: *Module, parent: nux.NodeID) !nux.NodeID {
    return (try self.nodes.new(parent)).id;
}
pub fn getPosition(self: *Module, id: nux.NodeID) !nux.Vec3 {
    return (try self.nodes.get(id)).position;
}
pub fn setPosition(self: *Module, id: nux.NodeID, position: nux.Vec3) !void {
    (try self.nodes.get(id)).position = position;
}
pub fn setParent(self: *Module, id: nux.NodeID, parent: nux.NodeID) !void {
    (try self.nodes.get(id)).parent = parent;
}
