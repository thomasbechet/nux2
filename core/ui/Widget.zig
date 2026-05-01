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
    fixed = 1,
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

    // Computed size
    box: nux.Box2i = .empty(0, 0), // Relative to parent
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

fn resolveSizing(sizing: Sizing, size: f32, available: i32) i32 {
    const raw: i32 = switch (sizing) {
        .fixed => @intFromFloat(size),
        .grow => available,
    };
    return @max(0, @min(available, raw));
}

fn layoutRecursive(self: *Self, widget: *Component, id: nux.ID, available: Available) !void {
    // 1. Resolve own size
    var size = nux.Vec2i.init(
        resolveSizing(widget.sizing_x, widget.size_x, available.max.x()),
        resolveSizing(widget.sizing_y, widget.size_y, available.max.y()),
    );
    widget.box.size = .init(@intCast(size.x()), @intCast(size.y()));

    // 2. Inner box (with padding)
    const pad = widget.padding;

    const inner = nux.Box2i.init(
        widget.box.pos.x() + pad.x(),
        widget.box.pos.y() + pad.z(),
        @intCast(size.x() - pad.x() - pad.y()),
        @intCast(size.y() - pad.z() - pad.w()),
    );

    // 3. Count children
    const is_row = widget.direction == .row;
    var total_fixed: i32 = 0;
    var total_weight: f32 = 0;
    var grow_count: i32 = 0;
    var child_count: i32 = 0;

    var it = try self.node.iterChildren(id);
    while (it.next()) |child_id| {
        const child = self.components.getOptional(child_id) orelse continue;

        const sizing = if (is_row) child.sizing_x else child.sizing_y;
        const size_val = if (is_row) child.size_x else child.size_y;

        switch (sizing) {
            .fixed => total_fixed += @intFromFloat(size_val),
            .grow => total_weight += if (size_val == 0) 1 else size_val,
        }

        child_count += 1;
        grow_count += 1;
    }

    const gap_total: i32 = @intCast((child_count - 1) * widget.gap);
    const main_available: i32 = if (is_row) @intCast(inner.w()) else @intCast(inner.h());
    var remaining = main_available - total_fixed - gap_total;
    if (remaining < 0) remaining = 0;
    const grow_size: i32 = if (grow_count > 0) @divTrunc(remaining, grow_count) else 0;

    // 4. Alignment offset (main axis)
    const content_size: i32 = total_fixed + gap_total + (grow_size * grow_count);
    const alignment = if (is_row) widget.alignment_x else widget.alignment_y;
    var cursor: i32 = switch (alignment) {
        .start => 0,
        .center => @divTrunc(main_available - content_size, 2),
        .end => (main_available - content_size),
    };

    // 5. Layout children
    it = try self.node.iterChildren(id);
    while (it.next()) |child_id| {
        const child = self.components.getOptional(child_id) orelse continue;

        // Size
        var child_w: i32 = 0;
        var child_h: i32 = 0;
        if (is_row) {
            child_w = switch (child.sizing_x) {
                .fixed => @intFromFloat(child.size_x),
                .grow => grow_size,
            };
            child_h = resolveSizing(child.sizing_y, child.size_y, @intCast(inner.h()));
        } else {
            child_h = switch (child.sizing_y) {
                .fixed => @intFromFloat(child.size_y),
                .grow => grow_size,
            };
            child_w = resolveSizing(child.sizing_x, child.size_x, @intCast(inner.w()));
        }

        // Cross axis alignment
        var offset_cross: i32 = 0;
        if (is_row) {
            const free = @as(i32, @intCast(inner.h())) - child_h;
            offset_cross = switch (widget.alignment_y) {
                .start => 0,
                .center => @divTrunc(free, 2),
                .end => free,
            };
        } else {
            const free = @as(i32, @intCast(inner.w())) - child_w;
            offset_cross = switch (widget.alignment_x) {
                .start => 0,
                .center => @divTrunc(free, 2),
                .end => free,
            };
        }

        // Position
        const child_x = if (is_row)
            inner.x() + cursor
        else
            inner.x() + offset_cross;

        const child_y = if (is_row)
            inner.y() + offset_cross
        else
            inner.y() + cursor;

        // Set child position
        child.box.pos = .init(child_x, child_y);

        // Layout on widget
        try self.layoutRecursive(child, child_id, .{
            .min = .zero(),
            .max = .init(child_w, child_h),
        });

        // Advance
        cursor += (if (is_row) child_w else child_h) + @as(i32, @intCast(widget.gap));
    }
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
    try self.layoutRecursive(widget, id, .{
        .min = .zero(),
        .max = .init(
            @intCast(width),
            @intCast(height),
        ),
    });
}
fn renderRecursive(
    self: *Self,
    id: nux.ID,
    viewport: *nux.Viewport.Component,
) !void {
    const widget = self.components.get(id) catch return;

    // Background
    if (!widget.background_color.isTransparent()) {
        try viewport.commands.rectangle(.{
            .box = widget.box,
            .color = widget.background_color,
        });
    }

    // Border
    if (widget.border_sizes.reduceMax() > 0) {
        const border = widget.border_sizes;
        const box = widget.box;
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
            .pos = widget.box.pos,
            .scale = 24 / 8,
            .color = label.color,
        });
    }

    // Render children
    var it = try self.node.iterChildren(id);
    while (it.next()) |child| {
        if (self.components.has(child)) {
            try self.renderRecursive(child, viewport);
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
    try self.renderRecursive(id, viewport);

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
