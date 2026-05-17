const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const SignalID = struct {
    index: usize,
};

pub const Stage = enum(u32) {
    start,
    pre_update,
    update,
    post_update,
    render,
    stop,
};

const Signal = struct {
    stage: Stage,
    callables: std.ArrayList(nux.Callable) = .empty,
};

const Event = struct {
    signal: nux.SignalID,
    source: nux.ID,
};

const ActiveEvent = struct {
    signal: nux.SignalID,
    source: nux.ID,
    index: usize,
};

const StageQueue = struct {
    update_signal: nux.SignalID,
    queue: nux.Deque(Event) = .empty,
};

allocator: nux.Platform.Allocator,
logger: *nux.Logger,
stages: std.EnumMap(Stage, StageQueue),
active_event: ?*ActiveEvent, // null if no active event (use by getSource)
signals: nux.ObjectPool(Signal),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.active_event = null;
    self.signals = .init(self.allocator);

    // Setup stages
    self.stages = .{};
    inline for (std.meta.fields(Stage)) |field| {
        const stage = @field(Stage, field.name);
        const update_signal = try self.createSignal(stage);
        self.stages.put(stage, .{
            .update_signal = update_signal,
        });
    }
}
pub fn deinit(self: *Self) void {

    // Deinit stages
    var stage_it = self.stages.iterator();
    while (stage_it.next()) |entry| {
        self.deleteSignal(entry.value.update_signal);
        entry.value.queue.deinit(self.allocator);
    }

    // Release resources
    self.signals.deinit();
}

fn dispatch(self: *Self, stage: nux.Event.Stage) !void {
    const stage_queue = self.stages.getPtr(stage) orelse unreachable;
    while (stage_queue.queue.popFront()) |e| {

        // Keep point to active event on the stack
        var active_event = ActiveEvent{
            .signal = e.signal,
            .source = e.source,
            .index = 0,
        };
        self.active_event = &active_event;

        // Iterate callbacks
        while (true) {

            // Check signal has been deleted
            const signal = self.signals.get(active_event.signal.index) orelse break;

            // Check end
            if (active_event.index >= signal.callables.items.len) {
                break;
            }

            // Call
            try signal.callables.items[active_event.index].call();

            // Next callback
            active_event.index += 1;
        }

        // Reset active signal
        self.active_event = null;
    }
}
pub fn update(self: *Self) !void {

    // Push stage update events
    var stage_it = self.stages.iterator();
    while (stage_it.next()) |entry| {
        try self.emit(entry.value.update_signal, .null);
    }

    // Dispatch all stages
    try self.dispatch(.pre_update);
    try self.dispatch(.update);
    try self.dispatch(.post_update);
    try self.dispatch(.render);

    // Clear stage queues
    stage_it = self.stages.iterator();
    while (stage_it.next()) |entry| {
        entry.value.queue.head = 0;
        entry.value.queue.len = 0;
    }
}

pub fn createSignal(
    self: *Self,
    stage: nux.Event.Stage,
) !nux.SignalID {
    const index = try self.signals.add(.{
        .stage = stage,
    });
    return .{ .index = index };
}
pub fn deleteSignal(self: *Self, id: nux.SignalID) void {
    const signal = self.signals.get(id.index) orelse return;
    signal.callables.deinit(self.allocator);
    self.signals.remove(id.index);
}
pub fn emit(self: *Self, id: nux.SignalID, source: nux.ID) !void {
    const signal = self.signals.get(id.index) orelse return;
    const stage_queue = self.stages.getPtr(signal.stage) orelse unreachable;
    try stage_queue.queue.pushBack(self.allocator, .{
        .signal = id,
        .source = source,
    });
}
pub fn bind(self: *Self, id: nux.SignalID, callable: nux.Callable) !void {
    const signal = self.signals.get(id.index) orelse return;
    try signal.callables.append(self.allocator, callable);
}
pub fn unbind(self: *Self, id: nux.SignalID, callable: nux.Callable) !void {
    const signal = self.signals.get(id.index) orelse return;

    // Find callback index
    var index: ?usize = null;
    for (signal.callables.items, 0..) |item, idx| {
        if (item.obj == callable.obj and item.callback == callable.callback) {
            index = idx;
            break;
        }
    }

    // Check active event
    if (index) |idx| {
        if (self.active_event) |active_event| {
            if (active_event.signal == id) {
                if (idx < active_event.index) {
                    active_event.index -= 1;
                }
            }
        }
    }
}
pub fn getSource(self: *Self) nux.ID {
    if (self.active_event) |event| {
        return event.source;
    }
    return .null;
}
pub fn getStageSignal(self: *Self, stage: nux.Event.Stage) nux.SignalID {
    const event_stage = self.stages.getPtr(stage) orelse unreachable;
    return event_stage.update_signal;
}
