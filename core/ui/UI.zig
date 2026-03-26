const std = @import("std");
const nux = @import("../nux.zig");
const clay = @import("zclay");

const Self = @This();

allocator: std.mem.Allocator,
node: *nux.Node,
widget: *nux.Widget,
viewport: *nux.Viewport,
container: *nux.Container,
button: *nux.Button,
font: *nux.Font,
window: *nux.Window,
clay_memory: []u8,

pub fn measureText(text: []const u8, config: *clay.TextElementConfig, _: *Self) clay.Dimensions {
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

fn sidebarItemComponent(_: *Self, index: u32, font: *nux.Font.Component) void {
    const sidebar_item_layout: clay.LayoutConfig = .{ .sizing = .{ .w = .fit } };
    const orange: clay.Color = .{ 225, 138, 50, 255 };
    clay.UI()(.{
        .id = .IDI("SidebarBlob", index),
        .layout = sidebar_item_layout,
        .background_color = orange,
    })({
        clay.text("Hello World", .{
            .font_size = 24,
            .user_data = @ptrCast(font),
            .color = .{ 255, 255, 255, 255 },
            .alignment = .left,
        });
    });
}

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
fn renderWidget(self: *Self, id: nux.ID) !void {
    const widget = self.widget.components.get(id) catch return;
    const name = try self.node.getName(id);
    clay.UI()(.{
        .id = .localID(name),
        .layout = .{
            .direction = @enumFromInt(@intFromEnum(widget.direction)),
            .sizing = .{ .w = .grow, .h = .grow },
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
        .background_color = colorToClay(widget.background_color),
    })({
        var it = try self.node.iterChildren(id);
        while (it.next()) |child| {
            if (self.widget.components.has(child)) {
                try self.renderWidget(child);
            }
        }
    });
}
pub fn onUpdate(self: *Self) !void {
    var it = self.viewport.components.iterator();
    while (it.next()) |entry| {
        if (entry.component.source == .ui) {
            clay.setLayoutDimensions(.{
                .w = @floatFromInt(self.window.width),
                .h = @floatFromInt(self.window.height),
            });
            clay.setPointerState(.{ .x = 0, .y = 0 }, false);
            clay.updateScrollContainers(false, .{ .x = 0, .y = 0 }, 0);
            clay.beginLayout();
            try self.renderWidget(entry.component.source.ui);
            const commands = clay.endLayout();

            const cb = &entry.component.commands;
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
                    .border => {},
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
    }

    // try self.gpu.render(&cb);
}
