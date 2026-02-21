const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Node = struct {
    callables: std.ArrayList(nux.Callable),
};

const SignalEvent = struct {
    signal: nux.ID,
    source: nux.ID,
};

nodes: nux.NodePool(Node),
allocator: nux.Platform.Allocator,
signal_queue: nux.Deque(SignalEvent),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn dispatchAll(self: *Self) !void {
    while (self.signal_queue.popFront()) |event| {
        // If the signal has been deleted, skip
        const signal = self.nodes.get(event.signal) catch continue;
        // Call signal
        signal.callables
    }
}

pub fn new(self: *Self, parent: nux.ID) !nux.ID {
    return try self.nodes.new(parent, .{
        .callables = .empty,
    });
}
pub fn emit(self: *Self, id: nux.ID, source: nux.ID) !void {
    _ = try self.nodes.get(id);
    const index = self.signal_queue.items.len;
    const event = try self.signal_queue.addOne(self.allocator);
    event.node = id;
    event.source = source;
    event.next = null;
    event.prev = self.signal_queue_last;
    if (self.signal_queue_first == null) {
        self.signal_queue_first = index;
    }
    if (self.signal_queue_last == null) {
        self.signal_queue_last = index;
    }
}
pub fn connect(self: *Self, id: nux.ID, callable: nux.Callable) !void {
    const node = try self.nodes.get(id);
    try node.callables.append(self.allocator, callable);
}
pub fn disconnect(self: *Self, id: nux.ID, callable: nux.Callable) !void {
    const node = try self.nodes.get(id);
    _ = node;
    _ = callable;
}
