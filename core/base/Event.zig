const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const ID = struct {
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

const Event = struct {
    stage: Stage,
    callables: std.ArrayList(nux.Callable) = .empty,
};

const EventCall = struct {
    event: nux.EventID,
    source: nux.ID,
};

const ActiveEventCall = struct {
    event: nux.EventID,
    index: usize,
};

const StageEvent = struct {
    udpate_event: nux.EventID,
    queue: nux.Deque(EventCall) = .empty,
};

allocator: nux.Platform.Allocator,
logger: *nux.Logger,
stages: std.EnumMap(Stage, StageEvent),
active_event: ?*ActiveEventCall,
events: nux.ObjectPool(Event),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.active_event = null;
    self.events = .init(self.allocator);

    // Setup stages
    self.stages = .{};
    inline for (std.meta.fields(Stage)) |field| {
        self.stages.put(@field(Stage, field.name), .{});
    }
    var it = self.stages.iterator();
    while (it.next()) |entry| {
        entry.value.queue = .empty;
        entry.value.update = try self.create(entry.key);
    }
}
pub fn deinit(self: *Self) void {
    self.events.deinit();

    // Deinit stages
    var it = self.stages.iterator();
    while (it.next()) |entry| {
        self.delete(entry.value.udpate_event);
        entry.value.queue.deinit(self.allocator);
    }
}
pub fn dispatch(self: *Self, stage: nux.Event.Stage) !void {
    const event_stage = self.stages.getPtr(stage) orelse unreachable;
    while (event_stage.queue.popFront()) |e| {

        // Keep reference to event
        var active_event = ActiveEventCall{
            .event = e.event,
            .index = 0,
        };
        self.active_event = &active_event;

        // Iterate callbacks
        while (true) {
            const event = self.events.get(active_event.event.index);

            // Check end
            if (active_event.index >= event.callables.items.len) {
                break;
            }

            // Call
            try event.callables.items[active_event.index].call();

            // Next callback
            active_event.index += 1;
        }

        // Reset active signal
        self.active_event = null;
    }
}

pub fn create(
    self: *Self,
    stage: nux.Stage,
) !nux.EventID {
    const index = try self.events.add(.{
        .stage = stage,
    });
    return .{ .index = index };
}
pub fn delete(self: *Self, id: nux.EventID) void {
    self.events.remove(id.index);
}
pub fn emit(self: *Self, id: nux.EventID, source: nux.ID) !void {
    const event = self.events.get(id.index);
    const event_queue = self.stages.getPtr(event.stage) orelse unreachable;
    try event_queue.pushBack(self.allocator, .{ .event = id, .source = source });
}
pub fn bind(self: *Self, id: nux.EventID, callable: nux.Callable) !void {
    const event = self.events.get(id.index);
    try event.callables.append(self.allocator, callable);
}
pub fn unbind(self: *Self, id: nux.EventID, callable: nux.Callable) !void {
    const event = self.events.get(id.index);

    // Find callback index
    var index: ?usize = null;
    for (event.callables.items, 0..) |item, idx| {
        if (item.obj == callable.obj and item.callback == callable.callback) {
            index = idx;
            break;
        }
    }

    // Check active event
    if (index) |idx| {
        if (self.active_event) |active_event| {
            if (active_event.event == id) {
                if (idx < active_event.index) {
                    active_event.index -= 1;
                }
            }
        }
    }
}
// pub fn getSource(self: *Self) nux.ID {
//     if (self.active_event) |event| {
//         // return event.
//     }
//     const event = try self.events.get(id.index);
// }
pub fn getStageUpdate(self: *Self, stage: nux.Event.Stage) !nux.EventID {
    const event_stage = self.stages.getPtr(stage) orelse return .null;
    return event_stage.udpate_event;
}
