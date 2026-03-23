const nux = @import("../nux.zig");

const Self = @This();

const Component = struct {
    parent: nux.ID = .null,
    box: nux.Box2i = .empty(0, 0),
    background_color: nux.Color = .red,
};

node: *nux.Node,
components: nux.Components(Component),

pub fn setParent(self: *Self, id: nux.ID, parent: nux.ID) !void {
    const widget = try self.components.get(id);
    widget.parent = parent;
}
pub fn setBackgroundColor(self: *Self, id: nux.ID, color: nux.Color) !void {
    const widget = try self.components.get(id);
    widget.background_color = color;
}
pub fn getBackgroundColor(self: *Self, id: nux.ID) !nux.Color {
    const widget = try self.components.get(id);
    return widget.background_color;
}
