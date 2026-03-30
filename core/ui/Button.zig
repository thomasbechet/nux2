const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

const Component = struct {
    onClick: nux.ID = .null,
};

node: *nux.Node,
components: nux.Components(Component),
signal: *nux.Signal,

pub fn click(self: *Self, id: nux.ID) !void {
    const component = try self.components.get(id);
    try self.signal.emit(component.onClick, id);
}

pub fn onClick(self: *Self, id: nux.ID, callabe: nux.Callable) !void {}
