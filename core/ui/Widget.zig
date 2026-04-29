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

pub const Layout = enum(u32) {
    container,
    stack,
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
    layout: Layout = .container,

    // Computed size
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

fn layoutRecursive(self: *Self, id: nux.ID, available: nux.Vec2i) !nux.Vec2i {
    const widget = self.components.getOptional(id) orelse return .zero();
    var size_x: i32 = available.x();
    var size_y: i32 = available.y();

    switch (widget.layout) {
        .container => {},
        .stack => {},
    }

    // Remove padding
    size_x -= @max(0, widget.padding.x() - widget.padding.y());
    size_y -= @max(0, widget.padding.z() - widget.padding.w());

    // Label
    if (self.label.components.getOptional(id)) |label| {
        return .init(@intCast(label.text.items.len * 8), 24);
    }

    // Iterate children
    var it = try self.node.iterChildren(id);
    while (it.next()) |child_id| {
        _ = child_id;
        // const consumed = try self.layoutRecursive(child_id, .init(size_x, size_y));
        // size_x -= consumed.x();
        // size_y -= consumed.y();

        // // Gap
        // if (widget.direction == .row) {
        //     size_x -= widget.gap;
        // } else {
        //     size_y -= widget.gap;
        // }
    }

    return .init(size_x, size_y);
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

    // Compute widget layout
    _ = try self.layoutRecursive(id, .init(
        @intCast(width),
        @intCast(height),
    ));
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
pub fn setLayout(self: *Self, id: nux.ID, layout: nux.Widget.Layout) !void {
    const widget = try self.components.get(id);
    widget.layout = layout;
}
