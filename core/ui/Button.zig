const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

const Component = struct {
    onClick: nux.EventID = .null,

    pub fn init(mod: *Self) !Component {
        return .{
            // .onClick = mod.event.create()
        };
    }
};

node: *nux.Node,
components: nux.Components(Component),
event: *nux.Event,

pub fn click(self: *Self, id: nux.ID) !void {
    const component = try self.components.get(id);
    try self.event.emit(component.onClick, id);
}
