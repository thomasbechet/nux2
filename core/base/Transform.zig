const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

nodes: nux.NodePool(struct {
    parent: nux.NodeID = .null,
    position: nux.Vec3 = .zero(),
    scale: nux.Vec3 = .scalar(1),
    rotation: nux.Quat = .identity(),
    pub fn init(_: *Self) !@This() {
        return .{};
    }
    pub fn deinit(_: *Self, _: *@This()) void {}
    pub fn save(_: *Self, writer: *nux.Writer, data: *@This()) !void {
        try writer.write(data.*);
    }
    pub fn load(_: *Self, reader: *nux.Reader, data: *@This()) !void {
        data.* = try reader.read(@This());
    }
}),
node: *nux.Node,
logger: *nux.Logger,

pub fn new(self: *Self, parent: nux.NodeID) !nux.NodeID {
    return (try self.nodes.new(parent)).id;
}
pub fn getPosition(self: *Self, id: nux.NodeID) !nux.Vec3 {
    return (try self.nodes.get(id)).position;
}
pub fn setPosition(self: *Self, id: nux.NodeID, position: nux.Vec3) !void {
    (try self.nodes.get(id)).position = position;
}
pub fn setParent(self: *Self, id: nux.NodeID, parent: nux.NodeID) !void {
    (try self.nodes.get(id)).parent = parent;
}
