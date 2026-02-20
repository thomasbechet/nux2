const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Callable = struct {
    callback: *const fn (*anyopaque) anyerror!void,
};

const Node = struct {
    callables: std.ArrayList(Callable),
};

nodes: nux.NodePool(Node),
allocator: nux.Platform.Allocator,
signal_queue: std.DoublyLinkedList,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn dispatch(self: *Self) !void {}

pub fn new(self: *Self, parent: nux.ID) !nux.ID {
    return try self.nodes.new(parent, .{
        .callables = .empty,
    });
}
pub fn emit(self: *Self, id: nux.ID, source: nux.ID) !void {
    const node = try self.nodes.get(id);
    _ = node;
    _ = source;
}
pub fn connect(self: *Self, id: nux.ID, callable: Callable) !void {
    const node = try self.nodes.get(id);
    try node.callables.append(self.allocator, callable);
}
pub fn disconnect(self: *Self, id: nux.ID, callable: Callable) !void {
    const node = try self.nodes.get(id);
    _ = node;
    _ = callable;
}
