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
    const element = try self.components.get(id);
    element.parent = parent;
}
pub fn setBackgroundColor(self: *Self, id: nux.ID, color: nux.Color) !void {
    const element = try self.components.get(id);
    element.background_color = color;
}
pub fn getBackgroundColor(self: *Self, id: nux.ID) !nux.Color {
    const element = try self.components.get(id);
    return element.background_color;
}
