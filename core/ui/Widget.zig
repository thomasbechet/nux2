const nux = @import("../nux.zig");
const std = @import("std");
const clay = @import("zclay");

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
    background_color: nux.Color = .transparent,
    padding: nux.Vec4i = .zero(),
    direction: Direction = .top_to_bottom,
    alignX: AlignmentX = .left,
    alignY: AlignmentY = .top,
    child_gap: u32 = 0,
    sizing_x: Sizing = .fit,
    sizing_y: Sizing = .fit,
    minmax_x: nux.Vec2i = .zero(),
    minmax_y: nux.Vec2i = .zero(),
    border_width: nux.Vec4i = .zero(),
    border_color: nux.Color = .white,
    border_radius: nux.Vec4i = .zero(),
};

components: nux.Components(Component),
allocator: std.mem.Allocator,
node: *nux.Node,
label: *nux.Label,
button: *nux.Button,
font: *nux.Font,
texture: *nux.Texture,
window: *nux.Window,
clay_memory: []u8,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;

    // Initialize clay
    const min_memory_size: u32 = clay.minMemorySize();
    self.clay_memory = try self.allocator.alloc(u8, min_memory_size);
    errdefer self.allocator.free(self.clay_memory);
    const arena: clay.Arena = clay.createArenaWithCapacityAndMemory(self.clay_memory);
    _ = clay.initialize(arena, .{ .h = 1000, .w = 1000 }, .{});
    clay.setMeasureTextFunction(*Self, self, measureText);
}
pub fn deinit(self: *Self) void {
    self.allocator.free(self.clay_memory);
}

fn colorToClay(color: nux.Color) clay.Color {
    return color.rgba.mul(.scalar(255)).data;
}

fn measureText(text: []const u8, config: *clay.TextElementConfig, _: *Self) clay.Dimensions {
    var text_width: u32 = 0;
    var max_text_height: u32 = 0;

    const font: *nux.Font.Component = @ptrCast(@alignCast(config.user_data));
    var it = font.iterate(text);
    while (it.next()) |entry| {
        const glyph = entry.glyph;
        if (entry.codepoint != '\n') {
            text_width += glyph.box.w() + config.letter_spacing + 1;
            max_text_height = @max(max_text_height, glyph.box.h());
        } else {
            // max_text_width = @max(max_text_width, text_width);
            // text_width = 0;
            // text_height += font_size + @as(u32, @intCast(config.line_height));
        }
    }
    const scale_factor = (config.font_size / max_text_height) + 1;

    return clay.Dimensions{
        .h = @floatFromInt(max_text_height * scale_factor),
        .w = @floatFromInt(text_width * scale_factor),
    };
}

fn renderWidgetRecursive(self: *Self, id: nux.ID) !void {
    const widget = self.components.get(id) catch return;
    const name = try self.node.getName(id);
    clay.UI()(.{
        .id = .localID(name),
        .layout = .{
            .direction = @enumFromInt(@intFromEnum(widget.direction)),
            .sizing = .{
                .w = .{
                    .type = @enumFromInt(@intFromEnum(widget.sizing_x)),
                    .size = if (widget.sizing_x == .percent) .{
                        .percent = @floatFromInt(widget.minmax_x.x()),
                    } else .{
                        .minmax = .{
                            .min = @floatFromInt(widget.minmax_x.x()),
                            .max = @floatFromInt(widget.minmax_x.y()),
                        },
                    },
                },
                .h = .{
                    .type = @enumFromInt(@intFromEnum(widget.sizing_y)),
                    .size = if (widget.sizing_y == .percent) .{
                        .percent = @floatFromInt(widget.minmax_y.x()),
                    } else .{
                        .minmax = .{
                            .min = @floatFromInt(widget.minmax_y.x()),
                            .max = @floatFromInt(widget.minmax_y.y()),
                        },
                    },
                },
            },
            .padding = .{
                .left = @intCast(widget.padding.x()),
                .right = @intCast(widget.padding.y()),
                .top = @intCast(widget.padding.z()),
                .bottom = @intCast(widget.padding.w()),
            },
            .child_alignment = .{
                .x = @enumFromInt(@intFromEnum(widget.alignX)),
                .y = @enumFromInt(@intFromEnum(widget.alignY)),
            },
            .child_gap = @intCast(widget.child_gap),
        },
        .border = .{
            .color = colorToClay(widget.border_color),
            .width = .{
                .left = @intCast(widget.border_width.x()),
                .right = @intCast(widget.border_width.y()),
                .top = @intCast(widget.border_width.z()),
                .bottom = @intCast(widget.border_width.w()),
                .between_children = 0,
            },
        },
        .background_color = colorToClay(widget.background_color),
    })({

        // Label
        if (self.label.components.getOptional(id)) |label| {
            const font = try self.font.components.get(try self.font.default());
            clay.text(label.text.items, .{
                .font_size = 24,
                .color = colorToClay(label.color),
                .user_data = @ptrCast(font),
                .alignment = .center,
            });
        }

        // Button
        // if (self.button.components.getOptional(id)) |button| {}

        // Render children
        var it = try self.node.iterChildren(id);
        while (it.next()) |child| {
            if (self.components.has(child)) {
                try self.renderWidgetRecursive(child);
            }
        }
    });
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

    // Setup clay
    clay.setLayoutDimensions(.{
        .w = @floatFromInt(width),
        .h = @floatFromInt(height),
    });
    clay.setPointerState(.{ .x = 0, .y = 0 }, false);
    clay.updateScrollContainers(false, .{ .x = 0, .y = 0 }, 0);

    // Render widgets
    clay.beginLayout();
    try self.renderWidgetRecursive(id);
    const commands = clay.endLayout();

    // Generate graphics commands
    const cb = &viewport.commands;
    for (commands) |command| {
        const box = nux.Box2i.init(
            @intFromFloat(command.bounding_box.x),
            @intFromFloat(command.bounding_box.y),
            @intFromFloat(command.bounding_box.width),
            @intFromFloat(command.bounding_box.height),
        );
        switch (command.command_type) {
            .none => {},
            .rectangle => {
                try cb.rectangle(.{
                    .box = box,
                    .color = .fromRGBA255(command.render_data.rectangle.background_color),
                });
            },
            .border => {
                const color = nux.Color.fromRGBA255(command.render_data.border.color);
                const border = command.render_data.border.width;
                const rectangles: [4]nux.Box2i = .{
                    .init(box.x(), box.y(), border.left, box.h()), // left
                    .init(box.tr().x() - border.left, box.y(), border.left, box.h()), // right
                    .init(box.x(), box.y(), box.w(), border.top), // top
                    .init(box.x(), box.br().y() - border.bottom, box.w(), border.bottom), // bottom
                };
                for (rectangles) |rect| {
                    try cb.rectangle(.{
                        .box = rect,
                        .color = color,
                    });
                }
            },
            .text => {
                const len: usize = @intCast(command.render_data.text.string_contents.length);
                try cb.text(.{
                    .text = command.render_data.text.string_contents.chars[0..len],
                    .pos = box.pos,
                    .scale = command.render_data.text.font_size / 8,
                    .color = .fromRGBA255(command.render_data.text.text_color),
                });
            },
            .image => {
                // try cb.blit(.{
                //     .box = box,
                //     .pos = box.pos,
                // });
            },
            .scissor_start => {
                try cb.scissor(box);
            },
            .scissor_end => {
                try cb.scissor(null);
            },
            .custom => {},
        }
    }
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
pub fn setSizeX(
    self: *Self,
    id: nux.ID,
    sizing: nux.Widget.Sizing,
    min: u32,
    max: u32,
) !void {
    const widget = try self.components.get(id);
    widget.sizing_x = sizing;
    widget.minmax_x = .init(@intCast(min), @intCast(max));
}
pub fn setSizeY(
    self: *Self,
    id: nux.ID,
    sizing: nux.Widget.Sizing,
    min: u32,
    max: u32,
) !void {
    const widget = try self.components.get(id);
    widget.sizing_y = sizing;
    widget.minmax_y = .init(@intCast(min), @intCast(max));
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
