const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

pub const Direction = enum(u32) {
    row = 0,
    column = 1,
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
    background_color: nux.Color = .transparent,
    padding: nux.Vec4i = .zero(), // left, right, top, bottom
    direction: Direction = .column,
    alignX: AlignmentX = .left,
    alignY: AlignmentY = .top,
    child_gap: u32 = 0,
    sizing_x: Sizing = .fit,
    sizing_y: Sizing = .fit,
    size_x: f32 = 0, // float to support percent
    size_y: f32 = 0, // float to support percent
    border_width: nux.Vec4i = .zero(),
    border_color: nux.Color = .white,
    border_radius: nux.Vec4i = .zero(),

    // Computed layout
    box: nux.Box2i = .empty(0, 0),
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

// fn measureText(text: []const u8, config: *clay.TextElementConfig, _: *Self) clay.Dimensions {
//     var text_width: u32 = 0;
//     var max_text_height: u32 = 0;

//     const font: *nux.Font.Component = @ptrCast(@alignCast(config.user_data));
//     var it = font.iterate(text);
//     while (it.next()) |entry| {
//         const glyph = entry.glyph;
//         if (entry.codepoint != '\n') {
//             text_width += glyph.box.w() + config.letter_spacing + 1;
//             max_text_height = @max(max_text_height, glyph.box.h());
//         } else {
//             // max_text_width = @max(max_text_width, text_width);
//             // text_width = 0;
//             // text_height += font_size + @as(u32, @intCast(config.line_height));
//         }
//     }
//     const scale_factor = (config.font_size / max_text_height) + 1;

//     return clay.Dimensions{
//         .h = @floatFromInt(max_text_height * scale_factor),
//         .w = @floatFromInt(text_width * scale_factor),
//     };
// }

fn resolveSizing(sizing: Sizing, size: f32, available: u32) i32 {
    const raw: i32 = switch (sizing) {
        .fixed => @intFromFloat(size),
        .percent => @intFromFloat((@as(f32, @floatFromInt(available)) * size)),
        .grow => @intCast(available), // temporary, refined later
        .fit => @intCast(available),
    };
    return @max(0, @min(available, raw));
}
// fn layoutWidgetRecursive(self: *Self, id: nux.ID, available: nux.Box2i) !void {
//     const widget = self.components.get(id) catch return;

//     // 1. Resolve own size
//     var size: nux.Vec2i = .init(
//         resolveSizing(widget.sizing_x, widget.size_x, available.w()),
//         resolveSizing(widget.sizing_y, widget.size_y, available.h()),
//     );
//     widget.box = .init(
//         available.x(),
//         available.y(),
//         @intCast(size.x()),
//         @intCast(size.y()),
//     );

//     // 2. Compute inner
//     const pad = widget.padding;
//     const inner: nux.Box2i = .init(
//         pad.x(),
//         pad.y(),
//         @intCast(size.x() - pad.x() - pad.y()),
//         @intCast(size.y() - pad.z() - pad.w()),
//     );

//     // 2. Render children
//     var it = try self.node.iterChildren(id);
//     while (it.next()) |child| {
//         if (self.components.has(child)) {
//             try self.layoutWidgetRecursive(child, inner);
//         }
//     }
// }
fn layoutWidgetRecursive(self: *Self, id: nux.ID, available: nux.Box2i) !void {
    const widget = self.components.get(id) catch return;

    // 1. Resolve own size
    var size = nux.Vec2i.init(
        resolveSizing(widget.sizing_x, widget.size_x, available.w()),
        resolveSizing(widget.sizing_y, widget.size_y, available.h()),
    );

    widget.box = .init(
        available.x(),
        available.y(),
        @intCast(size.x()),
        @intCast(size.y()),
    );

    // 2. Inner box (with padding)
    const pad = widget.padding;
    const inner = nux.Box2i.init(
        available.x() + pad.x(),
        available.y() + pad.z(),
        @intCast(size.x() - pad.x() - pad.y()),
        @intCast(size.y() - pad.z() - pad.w()),
    );

    // 3. Measure fixed + percent, count grow
    const is_row = widget.direction == .row;
    var total_fixed: i32 = 0;
    var grow_count: i32 = 0;
    var child_count: usize = 0;

    var it = try self.node.iterChildren(id);
    while (it.next()) |child_id| {
        const child = self.components.getOptional(child_id) orelse continue;

        child_count += 1;

        const sizing = if (is_row) child.sizing_x else child.sizing_y;
        const size_val = if (is_row) child.size_x else child.size_y;
        const avail = if (is_row) inner.w() else inner.h();

        switch (sizing) {
            .fixed => total_fixed += @intFromFloat(size_val),
            .percent => total_fixed += @intFromFloat(@as(f32, @floatFromInt(avail)) * size_val),
            .grow => grow_count += 1,
            .fit => grow_count += 1, // treat like grow for now
        }
    }
    if (child_count == 0) return;

    const gap_total: i32 = @intCast((child_count - 1) * widget.child_gap);
    const main_available: i32 = if (is_row) @intCast(inner.w()) else @intCast(inner.h());

    var remaining = main_available - total_fixed - gap_total;
    if (remaining < 0) remaining = 0;

    const grow_size: i32 = if (grow_count > 0) @divTrunc(remaining, grow_count) else 0;

    // 4. Alignment offset
    const content_size: i32 = total_fixed + gap_total + (grow_size * grow_count);

    var cursor: i32 = undefined;
    if (is_row) {
        cursor = switch (widget.alignX) {
            .left => 0,
            .center => @divTrunc((main_available - content_size), 2),
            .right => (main_available - content_size),
        };
    } else {
        cursor = switch (widget.alignY) {
            .top => 0,
            .center => @divTrunc((main_available - content_size), 2),
            .bottom => (main_available - content_size),
        };
    }

    // 5. Layout children
    it = try self.node.iterChildren(id);
    while (it.next()) |child_id| {
        const child = self.components.getOptional(child_id) orelse continue;

        var child_w: i32 = 0;
        var child_h: i32 = 0;

        // Compute child size
        if (is_row) {
            child_w = switch (child.sizing_x) {
                .fixed => @intFromFloat(child.size_x),
                .percent => @intFromFloat(@as(f32, @floatFromInt(inner.w())) * child.size_x),
                .grow, .fit => grow_size,
            };
            child_h = resolveSizing(child.sizing_y, child.size_y, inner.h());
        } else {
            child_h = switch (child.sizing_y) {
                .fixed => @intFromFloat(child.size_y),
                .percent => @intFromFloat(@as(f32, @floatFromInt(inner.h())) * child.size_y),
                .grow, .fit => grow_size,
            };
            child_w = resolveSizing(child.sizing_x, child.size_x, inner.w());
        }

        // Compute alignment
        var offset_cross: i32 = 0;
        if (is_row) {
            const free = @as(i32, @intCast(inner.h())) - child_h;
            offset_cross = switch (widget.alignY) {
                .top => 0,
                .center => @divTrunc(free, 2),
                .bottom => free,
            };
        } else {
            const free = @as(i32, @intCast(inner.w())) - child_w;
            offset_cross = switch (widget.alignX) {
                .left => 0,
                .center => @divTrunc(free, 2),
                .right => free,
            };
        }

        // Compute child position
        const child_x = if (is_row)
            inner.x() + cursor
        else
            inner.x() + offset_cross;

        const child_y = if (is_row)
            inner.y() + offset_cross
        else
            inner.y() + cursor;

        const child_box = nux.Box2i.init(
            child_x,
            child_y,
            @intCast(child_w),
            @intCast(child_h),
        );

        // Compute child layout
        try self.layoutWidgetRecursive(child_id, child_box);

        // Advance cursor
        cursor += (if (is_row) child_w else child_h) + @as(i32, @intCast(widget.child_gap));
    }
}
pub fn layoutWidget(self: *Self, id: nux.ID, viewport: *nux.Viewport.Component) !void {

    // Compute viewport size
    var width = self.window.width;
    var height = self.window.height;
    if (viewport.target) |texture_id| {
        const texture = try self.texture.components.get(texture_id);
        width = texture.info.width;
        height = texture.info.height;
    }

    // Recursive compute
    try self.layoutWidgetRecursive(id, .init(0, 0, @intCast(width), @intCast(height)));
}
fn renderWidgetRecursive(
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
    if (widget.border_width.reduceMax() > 0) {
        const border = widget.border_width;
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
            try self.renderWidgetRecursive(child, viewport);
        }
    }
}

pub fn renderWidget(self: *Self, id: nux.ID, viewport: *nux.Viewport.Component) !void {

    // Compute viewport size
    var width = self.window.width;
    var height = self.window.height;
    if (viewport.target) |texture_id| {
        const texture = try self.texture.components.get(texture_id);
        width = texture.info.width;
        height = texture.info.height;
    }

    // Render root widget
    try self.renderWidgetRecursive(id, viewport);

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
pub fn setWidth(
    self: *Self,
    id: nux.ID,
    sizing: nux.Widget.Sizing,
    width: f32,
) !void {
    const widget = try self.components.get(id);
    widget.sizing_x = sizing;
    widget.size_x = @max(width, 0);
}
pub fn setHeight(
    self: *Self,
    id: nux.ID,
    sizing: nux.Widget.Sizing,
    height: f32,
) !void {
    const widget = try self.components.get(id);
    widget.sizing_y = sizing;
    widget.size_y = @max(height, 0);
}
pub fn setBorder(self: *Self, id: nux.ID, width: nux.Vec4i) !void {
    const widget = try self.components.get(id);
    widget.border_width = width;
}
pub fn setBorderColor(self: *Self, id: nux.ID, color: nux.Color) !void {
    const widget = try self.components.get(id);
    widget.border_color = color;
}
pub fn setBorderRadius(self: *Self, id: nux.ID, radius: nux.Vec4i) !void {
    const widget = try self.components.get(id);
    widget.border_radius = radius;
}
