const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const ID = struct {
    index: usize,
};

const Component = struct {
    callables: std.ArrayList(nux.Callable) = .empty,
};

const Event = struct {
    event: nux.ID,
    source: nux.ID,
};

const ActiveEvent = struct {
    event: nux.ID,
    index: usize,
};

components: nux.Components(Component),
allocator: nux.Platform.Allocator,
signal_queue: nux.Deque(Event),
active_event: ?*ActiveEvent,
logger: *nux.Logger,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.active_event = null;
    self.signal_queue = try .initCapacity(self.allocator, 64);
}
pub fn deinit(self: *Self) void {
    self.signal_queue.deinit(self.allocator);
}
pub fn onPostUpdate(self: *Self) !void {
    while (self.signal_queue.popFront()) |event| {

        // Keep reference to signal
        var active_signal = ActiveEvent{
            .event = event.event,
            .index = 0,
        };
        self.active_event = &active_signal;

        // Iterate callbacks
        while (true) {
            const signal = self.components.get(active_signal.event) catch break;

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
        self.active_event = null;
    }
}

pub fn create(self: *Self, id: nux.ID, name: []const u8) !nux.EventID {
    _ = self;
    _ = id;
    _ = name;
    return .{ .index = 0 };
}
pub fn delete(self: *Self, id: nux.EventID) !void {
    _ = self;
    _ = id;
}
pub fn emit(self: *Self, id: nux.ID, source: nux.ID) !void {
    _ = try self.components.get(id);
    try self.signal_queue.pushBack(self.allocator, .{ .event = id, .source = source });
}
pub fn bind(self: *Self, id: nux.ID, callable: nux.Callable) !void {
    const component = try self.components.get(id);
    try component.callables.append(self.allocator, callable);
}
pub fn unbind(self: *Self, id: nux.ID, callable: nux.Callable) !void {
    const component = try self.components.get(id);

    // Find callback index
    var index: ?usize = null;
    for (component.callables.items, 0..) |item, idx| {
        if (item.obj == callable.obj and item.callback == callable.callback) {
            index = idx;
            break;
        }
    }

    // Check active event
    if (index) |idx| {
        if (self.active_event) |active_signal| {
            if (active_signal.event == id) {
                if (idx < active_signal.index) {
                    active_signal.index -= 1;
                }
            }
        }
    }
}
