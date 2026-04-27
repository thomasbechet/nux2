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
    fit = 0,
    grow = 1,
    percent = 2,
    fixed = 3,
};

const Dimension = enum(usize) {
    const size: usize = 2;
    x = 0,
    y = 1,
};

const Component = struct {
    background_color: nux.Color = .transparent,
    padding: nux.Vec4i = .zero(), // left, right, top, bottom
    border_sizes: nux.Vec4i = .zero(),
    border_color: nux.Color = .white,
    border_radius: nux.Vec4i = .zero(),
    direction: Direction = .column,
    alignment: [Dimension.size]Alignment = .{.start} ** Dimension.size,
    gap: u32 = 0,
    sizing: [Dimension.size]Sizing = .{.fit} ** Dimension.size,
    size: [Dimension.size]f32 = .{0} ** Dimension.size, // float to support percent
};

const Available = struct {
    min: nux.Vec2i,
    max: nux.Vec2i,
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

fn measureWidget(self: *Self, available: u32, id: nux.ID) i32 {
    if (self.label.components.getOptional(id)) |label| {
        _ = label;
        return 24;
    }
    return @intCast(available);
}
fn resolveSizing(
    self: *Self,
    sizing: Sizing,
    size: f32,
    available: u32,
    id: nux.ID,
) i32 {
    const raw: i32 = switch (sizing) {
        .fixed => @intFromFloat(size),
        .percent => @intFromFloat((@as(f32, @floatFromInt(available)) * size)),
        .grow => @intCast(available), // temporary, refined later
        .fit => self.measureWidget(available, id),
    };
    return @max(0, @min(available, raw));
}

// - Constraints are given by parent with available parameter (min and max size).
// - The widget compute its size using parent constraints.
// - Parent position its children.
fn layoutWidgetRecursive(self: *Self, id: nux.ID, available: Available) !nux.Vec2i {
    const widget = self.components.get(id) catch return;

    // Apply padding
    var inner: nux.Vec2i = undefined;
    switch (widget.sizing[0]) {
        .fit => {
            // iter childs and add children
        },
        .grow => {
            inner = available.max;
        },
        .fixed => {
            inner = widget.size;
        },
        .percent => {
            inner = available.max.mul
        },
    }

    var child_count: usize = 0;
    var it = try self.node.iterChildren(id);
    while (it.next()) |child_id| {
        const child = self.components.getOptional(child_id) orelse continue;

        child_count += 1;

        const child_size = self.layoutWidgetRecursive(child_id, inner);

        switch (sizing) {
            .fixed => total_fixed += @intFromFloat(size_val),
            .percent => total_fixed += @intFromFloat(@as(f32, @floatFromInt(avail)) * size_val),
            .grow => grow_count += 1,
            .fit => grow_count += 1, // treat like grow for now
        }
    }
    if (child_count == 0) return;
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
    widget.gap = gap;
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
