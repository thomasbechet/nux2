const nux = @import("../nux.zig");

const Self = @This();

pub const Direction = enum(u32) {
    left_to_right = 0,
    top_to_bottom = 1,
};

pub const AlignmentX = enum(u32) {
    left = 0,
    right = 1,
    center = 2,
};

pub const AlignmentY = enum(u32) {
    top = 0,
    bottom = 1,
    center = 2,
};

pub const Sizing = enum(u32) {
    fit = 0,
    grow = 1,
    percent = 2,
    fixed = 3,
};

const Component = struct {
    box: nux.Box2i = .empty(0, 0),
    background_color: nux.Color = .white,
    padding: nux.Vec4i = .zero(),
    direction: Direction = .left_to_right,
    alignX: AlignmentX = .left,
    alignY: AlignmentY = .top,
    child_gap: u32 = 0,
};

node: *nux.Node,
components: nux.Components(Component),

pub fn setBackgroundColor(self: *Self, id: nux.ID, color: nux.Color) !void {
    const widget = try self.components.get(id);
    widget.background_color = color;
}
pub fn setPadding(self: *Self, id: nux.ID, padding: nux.Vec4i) !void {
    const widget = try self.components.get(id);
    widget.padding = padding;
}
pub fn setDirection(self: *Self, id: nux.ID, direction: nux.Widget.Direction) !void {
    const widget = try self.components.get(id);
    widget.direction = direction;
}
pub fn setAlignX(self: *Self, id: nux.ID, alignment: nux.Widget.AlignmentX) !void {
    const widget = try self.components.get(id);
    widget.alignX = alignment;
}
pub fn setAlignY(self: *Self, id: nux.ID, alignment: nux.Widget.AlignmentY) !void {
    const widget = try self.components.get(id);
    widget.alignY = alignment;
}
pub fn setChildGap(self: *Self, id: nux.ID, gap: u32) !void {
    const widget = try self.components.get(id);
    widget.child_gap = gap;
}
