const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

const Component = struct {
    pressed: nux.SignalID,
    released: nux.SignalID,

    pub fn init(mod: *Self) !Component {
        return .{
            .pressed = try mod.event.createSignal(.update),
            .released = try mod.event.createSignal(.update),
        };
    }
    pub fn deinit(self: *Component, mod: *Self) void {
        mod.event.deleteSignal(self.pressed);
        mod.event.deleteSignal(self.released);
    }
};

node: *nux.Node,
components: nux.Components(Component),
event: *nux.Event,

pub fn click(self: *Self, id: nux.ID) !void {
    const component = try self.components.get(id);
    try self.event.emit(component.pressed, id);
}
pub fn getPressed(self: *Self, id: nux.ID) !nux.SignalID {
    const component = try self.components.get(id);
    return component.pressed;
}
pub fn getReleased(self: *Self, id: nux.ID) !nux.SignalID {
    const component = try self.components.get(id);
    return component.released;
}
