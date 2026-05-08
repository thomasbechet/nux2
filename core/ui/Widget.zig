const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

pub const Direction = enum(u32) {
    row = 0,
    column = 1,
};

pub const Alignment = enum(u32) {
    start = 0,
    end = 1,
    center = 2,
};

pub const Sizing = enum(u32) {
    grow = 0,
    fit = 1,
    fixed = 2,
};

const Available = struct {
    min: nux.Vec2i,
    max: nux.Vec2i,
};

const Size = struct {
    main: i32,
    cross: i32,

    fn update(self: *Size, consumed: nux.Vec2i, is_row: bool) void {
        self.main += if (is_row) consumed.x() else consumed.y();
        self.cross += @max(self.cross, if (is_row) consumed.y() else consumed.x());
    }
    fn fromVec2(v: nux.Vec2i, is_row: bool) Size {
        return .{
            .main = if (is_row) v.x() else v.y(),
            .cross = if (is_row) v.y() else v.x(),
        };
    }
    fn toVec2(self: Size, is_row: bool) nux.Vec2i {
        return .init(
            if (is_row) self.main else self.cross,
            if (is_row) self.cross else self.main,
        );
    }
};

const Component = struct {
    background_color: nux.Color = .transparent,
    padding: nux.Vec4i = .zero(), // left, right, top, bottom
    direction: Direction = .column,
    gap: i32 = 0,
    border_sizes: nux.Vec4i = .zero(),
    border_color: nux.Color = .white,
    border_radius: nux.Vec4i = .zero(),
    alignment_x: Alignment = .start,
    alignment_y: Alignment = .start,
    sizing_x: Sizing = .fit,
    sizing_y: Sizing = .fit,
    size_x: f32 = 0, // float for grow weights
    size_y: f32 = 0, // float for grow weights

    // Computed values
    size: nux.Vec2i = .zero(),
    pos: nux.Vec2i = .zero(),
};

components: nux.Components(Component),
allocator: std.mem.Allocator,
node: *nux.Node,
label: *nux.Label,
button: *nux.Button,
font: *nux.Font,
texture: *nux.Texture,
window: *nux.Window,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

fn measureWidget(self: *Self, available: nux.Vec2i, id: nux.ID) !nux.Vec2i {
    if (self.label.components.getOptional(id)) |label| {
        return try self.font.measure(try self.font.default(), label.text.items, label.scale, available);
    } else if (self.button.components.getOptional(id)) |button| {
        _ = button;
        return available;
    }
    return .zero();
}

fn layoutRecursive(self: *Self, widget: *Component, id: nux.ID, available: Available) !nux.Vec2i {
    const is_row = widget.direction == .row;

    // Inner
    const pad = widget.padding;
    const border = widget.border_sizes;
    const inner_size = nux.Vec2i.init(
        available.max.x() - pad.x() - pad.y() - border.x() - border.y(),
        available.max.y() - pad.z() - pad.w() - border.z() - border.w(),
    );
    const inner: Size = .fromVec2(
        inner_size,
        is_row,
    );

    // Measure content
    var content: Size = .fromVec2(try self.measureWidget(inner_size, id), is_row);

    // Layout intrinsic children
    var total_weight: f32 = 0;
    var grow_count: i32 = 0;
    var child_count: i32 = 0;
    var it = try self.node.iterChildren(id);
    while (it.next()) |child_id| {
        const child = self.components.getOptional(child_id) orelse continue;

        const sizing = if (is_row) child.sizing_x else child.sizing_y;
        const size_val = if (is_row) child.size_x else child.size_y;

        switch (sizing) {
            .fit => {
                // Compute consumed space from inner
                const consumed = try self.layoutRecursive(child, child_id, .{
                    .min = .zero(),
                    .max = inner_size,
                });
                content.update(consumed, is_row);
            },
            .grow => {
                // Keep track of weights and grow count
                total_weight += if (size_val == 0) 1 else size_val;
                grow_count += 1;
            },
            .fixed => {
                // Compute consumed size
                const consumed = try self.layoutRecursive(child, child_id, .{
                    .min = .zero(),
                    .max = .init(
                        @intFromFloat(child.size_x),
                        @intFromFloat(child.size_y),
                    ),
                });
                content.update(consumed, is_row);
            },
        }

        child_count += 1;
    }

    // Compute remaining space
    content.main += (child_count - 1) * widget.gap;
    const remaining = @max(0, inner.main - content.main);

    // Layout grow children
    if (remaining > 0) {
        it = try self.node.iterChildren(id);
        while (it.next()) |child_id| {
            const child = self.components.getOptional(child_id) orelse continue;
            const sizing = if (is_row) child.sizing_x else child.sizing_y;

            switch (sizing) {
                .grow => {
                    var weight = if (is_row) child.size_x else child.size_y;
                    if (weight == 0) weight = 1;
                    const grow_size_weighted: i32 = @intFromFloat((weight / total_weight) * @as(f32, @floatFromInt(remaining)));
                    const max = (Size{
                        .main = grow_size_weighted,
                        .cross = inner.cross,
                    }).toVec2(is_row);
                    const consumed = try self.layoutRecursive(child, child_id, .{
                        .min = max,
                        .max = max,
                    });
                    content.update(consumed, is_row);
                },
                else => {},
            }
        }
    }

    // Fit content
    const fit_size = content.toVec2(is_row).add(.init(
        pad.x() + pad.y() + border.x() + border.y(),
        pad.z() + pad.w() + border.z() + border.w(),
    ));
    widget.size = .init(
        switch (widget.sizing_x) {
            .grow => available.max.x(),
            .fit => fit_size.x(),
            .fixed => @intFromFloat(widget.size_x),
        },
        switch (widget.sizing_y) {
            .grow => available.max.y(),
            .fit => fit_size.y(),
            .fixed => @intFromFloat(widget.size_y),
        },
    );

    // Alignment offset (main axis)
    const main_alignment = if (is_row) widget.alignment_x else widget.alignment_y;
    const cross_alignment = if (is_row) widget.alignment_y else widget.alignment_x;
    var cursor: i32 = switch (main_alignment) {
        .start => 0,
        .center => @divTrunc(inner.main - content.main, 2),
        .end => inner.main - content.main,
    };

    // Place children
    it = try self.node.iterChildren(id);
    while (it.next()) |child_id| {
        const child = self.components.getOptional(child_id) orelse continue;
        const child_size = Size.fromVec2(child.size, is_row);

        // Alignment offset (cross axis)
        const free = inner.cross - child_size.cross;
        const offset_cross: i32 = switch (cross_alignment) {
            .start => 0,
            .center => @divTrunc(free, 2),
            .end => free,
        };

        // Position
        const child_x = if (is_row) cursor else offset_cross;
        const child_y = if (is_row) offset_cross else cursor;
        child.pos = .init(
            pad.x() + border.x() + child_x,
            pad.z() + border.z() + child_y,
        );

        // Advance
        cursor += child_size.main + widget.gap;
    }

    return widget.size;
}

pub fn layout(self: *Self, id: nux.ID, viewport: *nux.Viewport.Component) !void {

    // Compute viewport size
    var width = self.window.width;
    var height = self.window.height;
    if (viewport.target) |texture_id| {
        const texture = try self.texture.components.get(texture_id);
        width = texture.info.width;
        height = texture.info.height;
    }

    // Compute widget layout
    const widget = try self.components.get(id);
    _ = try self.layoutRecursive(widget, id, .{
        .min = .zero(),
        .max = .init(
            @intCast(width),
            @intCast(height),
        ),
    });
    widget.pos = .zero();
}
fn renderRecursive(
    self: *Self,
    id: nux.ID,
    viewport: *nux.Viewport.Component,
    offset: nux.Vec2i,
) !void {
    const widget = self.components.get(id) catch return;
    const pos = widget.pos.add(offset);
    const box = nux.Box2i.initVector(
        pos,
        widget.size,
    );

    // Background
    if (!widget.background_color.isTransparent()) {
        try viewport.commands.rectangle(.{
            .box = box,
            .color = widget.background_color,
        });
    }

    // Border
    if (widget.border_sizes.reduceMax() > 0) {
        const border = widget.border_sizes;
        const rectangles: [4]nux.Box2i = .{
            .init(box.x(), box.y(), @intCast(border.x()), box.h()), // left
            .init(box.tr().x() - border.x(), box.y(), @intCast(border.x()), box.h()), // right
            .init(box.x(), box.y(), box.w(), @intCast(border.z())), // top
            .init(box.x(), box.br().y() - border.w(), box.w(), @intCast(border.w())), // bottom
        };
        for (rectangles) |rect| {
            try viewport.commands.rectangle(.{
                .box = rect,
                .color = widget.border_color,
            });
        }
    }

    // Label
    if (self.label.components.getOptional(id)) |label| {
        // const font = try self.font.components.get(try self.font.default());
        try viewport.commands.text(.{
            .text = label.text.items,
            .box = box,
            .scale = label.scale,
            .color = label.color,
        });
    }

    // Render children
    var it = try self.node.iterChildren(id);
    while (it.next()) |child| {
        if (self.components.has(child)) {
            try self.renderRecursive(child, viewport, offset);
        }
    }
}

pub fn render(self: *Self, id: nux.ID, viewport: *nux.Viewport.Component) !void {

    // Compute viewport size
    var width = self.window.width;
    var height = self.window.height;
    if (viewport.target) |texture_id| {
        const texture = try self.texture.components.get(texture_id);
        width = texture.info.width;
        height = texture.info.height;
    }

    // Render root widget
    try self.renderRecursive(id, viewport, .zero());
}

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
pub fn setAlignX(self: *Self, id: nux.ID, alignment: nux.Widget.Alignment) !void {
    const widget = try self.components.get(id);
    widget.alignment_x = alignment;
}
pub fn setAlignY(self: *Self, id: nux.ID, alignment: nux.Widget.Alignment) !void {
    const widget = try self.components.get(id);
    widget.alignment_y = alignment;
}
pub fn setChildGap(self: *Self, id: nux.ID, gap: u32) !void {
    const widget = try self.components.get(id);
    widget.gap = @intCast(gap);
}
pub fn setBorder(self: *Self, id: nux.ID, width: nux.Vec4i) !void {
    const widget = try self.components.get(id);
    widget.border_sizes = width;
}
pub fn setBorderColor(self: *Self, id: nux.ID, color: nux.Color) !void {
    const widget = try self.components.get(id);
    widget.border_color = color;
}
pub fn setBorderRadius(self: *Self, id: nux.ID, radius: nux.Vec4i) !void {
    const widget = try self.components.get(id);
    widget.border_radius = radius;
}
pub fn setSizeX(self: *Self, id: nux.ID, sizing: nux.Widget.Sizing, size: f32) !void {
    const widget = try self.components.get(id);
    widget.sizing_x = sizing;
    widget.size_x = size;
}
pub fn setSizeY(self: *Self, id: nux.ID, sizing: nux.Widget.Sizing, size: f32) !void {
    const widget = try self.components.get(id);
    widget.sizing_y = sizing;
    widget.size_y = size;
}
