const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

pub const Property = enum(u32) {
    button_pressed = 0,
    button_released = 1,
    button_hovered = 2,
    checkbox_checked = 3,
    checkbox_unchecked = 4,
    cursor = 5,
};

const Image = struct {
    texture: nux.ID = .null,
    extent: nux.Box2i = .emptyZero(),
    inner: nux.Box2i = .emptyZero(),
};

const Component = struct {
    button: struct {
        pressed: Image = .{},
        released: Image = .{},
        hovered: Image = .{},
    } = .{},
    checkbox: struct {
        checked: Image = .{},
        unchecked: Image = .{},
    } = .{},
    cursor: Image = .{},
};

node: *nux.Node,
components: nux.Components(Component),

pub fn setImage(
    self: *Self,
    id: nux.ID,
    property: nux.StyleSheet.Property,
    texture: nux.ID,
    extent: nux.Box2i,
    inner: nux.Box2i,
) !void {
    const ss = try self.components.get(id);
    const image = Image{
        .texture = texture,
        .extent = extent,
        .inner = inner,
    };
    switch (property) {
        .button_pressed => ss.button.pressed = image,
        .button_released => ss.button.released = image,
        .button_hovered => ss.button.hovered = image,
        .checkbox_checked => ss.checkbox.checked = image,
        .checkbox_unchecked => ss.checkbox.unchecked = image,
        .cursor => ss.cursor = image,
    }
}
