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
};

const Available = struct {
    min: nux.Vec2i,
    max: nux.Vec2i,
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
    sizing_x: Sizing = .grow,
    sizing_y: Sizing = .grow,
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

fn measureWidget(self: *Self, available: nux.Vec2i, id: nux.ID) i32 {
    _ = available;
    if (self.label.components.getOptional(id)) |label| {
        return .init(
            @intCast(label.text.items.len * 8),
            24,
        );
    }
    return 0;
}

fn layoutRecursive(self: *Self, widget: *Component, id: nux.ID, available: Available) !nux.Vec2i {
    const is_row = widget.direction == .row;

    // Inner
    const pad = widget.padding;
    const inner = nux.Vec2i.init(
        available.max.x() - pad.x() - pad.y(),
        available.max.y() - pad.z() - pad.w(),
    );

    const main_inner = if (is_row) inner.x() else inner.y();
    const cross_inner = if (is_row) inner.y() else inner.x();

    // Measure content
    // const content = self.measureWidget(inner, id);

    // Layout intrinsic children
    var main_size: i32 = 0;
    var total_weight: f32 = 0;
    var grow_count: i32 = 0;
    var child_count: i32 = 0;
    var cross_size: i32 = 0;
    var it = try self.node.iterChildren(id);
    while (it.next()) |child_id| {
        const child = self.components.getOptional(child_id) orelse continue;

        const sizing = if (is_row) child.sizing_x else child.sizing_y;
        const size_val = if (is_row) child.size_x else child.size_y;

        switch (sizing) {
            .fit => {
                const consumed = try self.layoutRecursive(child, child_id, .{
                    .min = .zero(),
                    .max = inner,
                });
                main_size += if (is_row) consumed.x() else consumed.y();
                cross_size = @max(cross_size, if (is_row) consumed.y() else consumed.x());
            },
            .grow => {
                total_weight += if (size_val == 0) 1 else size_val;
                grow_count += 1;
            },
        }

        child_count += 1;
    }

    // Compute remaining space for grow children
    main_size += (child_count - 1) * widget.gap;
    const remaining = @max(0, main_size - main_inner);

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
                    const max = nux.Vec2i.init(
                        if (is_row) grow_size_weighted else inner.x(),
                        if (!is_row) grow_size_weighted else inner.y(),
                    );
                    const consumed = try self.layoutRecursive(child, child_id, .{
                        .min = max,
                        .max = max,
                    });
                    cross_size = @max(cross_size, if (is_row) consumed.y() else consumed.x());
                },
                else => {},
            }
        }
    }

    // Alignment offset (main axis)
    const alignment = if (is_row) widget.alignment_x else widget.alignment_y;
    var cursor: i32 = switch (alignment) {
        .start => 0,
        .center => @divTrunc(main_inner - main_size, 2),
        .end => (main_inner - main_size),
    };

    // Place children
    it = try self.node.iterChildren(id);
    while (it.next()) |child_id| {
        const child = self.components.getOptional(child_id) orelse continue;

        // Cross axis alignment
        // TODO: replace alignment with main / cross
        var offset_cross: i32 = 0;
        if (is_row) {
            const free = inner.y() - child.size.y();
            offset_cross = switch (widget.alignment_y) {
                .start => 0,
                .center => @divTrunc(free, 2),
                .end => free,
            };
        } else {
            const free = inner.x() - child.size.x();
            offset_cross = switch (widget.alignment_x) {
                .start => 0,
                .center => @divTrunc(free, 2),
                .end => free,
            };
        }

        // Position
        const child_x = if (is_row) cursor else offset_cross;
        const child_y = if (is_row) offset_cross else cursor;
        child.pos = .init(pad.x() + child_x, pad.z() + child_y);

        // Advance
        cursor += (if (is_row) child.size.x() else child.size.y()) + widget.gap;
    }

    const size = nux.Vec2i.init(
        if (widget.sizing_x == .grow) available.max.x() else (if (is_row) main_size else cross_size) + pad.x() + pad.y(),
        if (widget.sizing_y == .grow) available.max.y() else (if (is_row) main_size else cross_size) + pad.z() + pad.w(),
    );
    widget.size = size;
    std.log.info("{s} RETURN {}", .{ try self.node.getName(id), size });
    return size;
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
        widget.size.as(nux.vec.Vec(2, u32)),
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
            .pos = box.pos,
            .scale = 24 / 8,
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

    // // Generate graphics commands
    // const cb = &viewport.commands;
    // for (commands) |command| {
    //     const box = nux.Box2i.init(
    //         @intFromFloat(command.bounding_box.x),
    //         @intFromFloat(command.bounding_box.y),
    //         @intFromFloat(command.bounding_box.width),
    //         @intFromFloat(command.bounding_box.height),
    //     );
    //     switch (command.command_type) {
    //         .none => {},
    //         .rectangle => {
    //             try cb.rectangle(.{
    //                 .box = box,
    //                 .color = .fromRGBA255(command.render_data.rectangle.background_color),
    //             });
    //         },
    //         .border => {
    //             const color = nux.Color.fromRGBA255(command.render_data.border.color);
    //             const border = command.render_data.border.width;
    //             const rectangles: [4]nux.Box2i = .{
    //                 .init(box.x(), box.y(), border.left, box.h()), // left
    //                 .init(box.tr().x() - border.left, box.y(), border.left, box.h()), // right
    //                 .init(box.x(), box.y(), box.w(), border.top), // top
    //                 .init(box.x(), box.br().y() - border.bottom, box.w(), border.bottom), // bottom
    //             };
    //             for (rectangles) |rect| {
    //                 try cb.rectangle(.{
    //                     .box = rect,
    //                     .color = color,
    //                 });
    //             }
    //         },
    //         .text => {
    //             const len: usize = @intCast(command.render_data.text.string_contents.length);
    //             try cb.text(.{
    //                 .text = command.render_data.text.string_contents.chars[0..len],
    //                 .pos = box.pos,
    //                 .scale = command.render_data.text.font_size / 8,
    //                 .color = .fromRGBA255(command.render_data.text.text_color),
    //             });
    //         },
    //         .image => {
    //             // try cb.blit(.{
    //             //     .box = box,
    //             //     .pos = box.pos,
    //             // });
    //         },
    //         .scissor_start => {
    //             try cb.scissor(box);
    //         },
    //         .scissor_end => {
    //             try cb.scissor(null);
    //         },
    //         .custom => {},
    //     }
    // }
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
