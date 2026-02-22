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

const ActiveSignal = struct {
    signal: nux.ID,
    index: usize,
};

nodes: nux.NodePool(Node),
allocator: nux.Platform.Allocator,
signal_queue: nux.Deque(SignalEvent),
active_signal: ?*ActiveSignal,
logger: *nux.Logger,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.active_signal = null;
    self.signal_queue = try .initCapacity(self.allocator, 64);
}
pub fn deinit(self: *Self) void {
    self.signal_queue.deinit(self.allocator);
}
pub fn onPostUpdate(self: *Self) !void {
    while (self.signal_queue.popFront()) |event| {
        // Keep reference to signal
        var active_signal = ActiveSignal{
            .signal = event.signal,
            .index = 0,
        };
        self.active_signal = &active_signal;
        // Iterate callbacks
        while (true) {
            const signal = self.nodes.get(active_signal.signal) catch break;
            // Check end
            if (active_signal.index >= signal.callables.items.len) {
                break;
            }
            // Call
            try signal.callables.items[active_signal.index].call();
            // Next callback
            active_signal.index += 1;
        }
        // Reset active signal
        self.active_signal = null;
    }
}

pub fn new(self: *Self, parent: nux.ID) !nux.ID {
    return try self.nodes.new(parent, .{
        .callables = .empty,
    });
}
pub fn emit(self: *Self, id: nux.ID, source: nux.ID) !void {
    _ = try self.nodes.get(id);
    try self.signal_queue.pushBack(self.allocator, .{ .signal = id, .source = source });
}
pub fn connect(self: *Self, id: nux.ID, callable: nux.Callable) !void {
    const node = try self.nodes.get(id);
    try node.callables.append(self.allocator, callable);
}
pub fn disconnect(self: *Self, id: nux.ID, callable: nux.Callable) !void {
    const node = try self.nodes.get(id);
    // Find callback index
    var index: ?usize = null;
    for (node.callables.items, 0..) |item, idx| {
        if (item.obj == callable.obj and item.callback == callable.callback) {
            index = idx;
            break;
        }
    }
    if (index) |idx| {
        // Check active signal
        if (self.active_signal) |active_signal| {
            if (active_signal.signal == id) {
                if (idx < active_signal.index) {
                    active_signal.index -= 1;
                }
            }
        }
    }
}
