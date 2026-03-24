const std = @import("std");
const nux = @import("../nux.zig");
const clay = @import("zclay");

const Self = @This();

allocator: std.mem.Allocator,
node: *nux.Node,
element: *nux.UIElement,
viewport: *nux.Viewport,
container: *nux.Container,
button: *nux.Button,
font: *nux.Font,
window: *nux.Window,
gpu: *nux.GPU,
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
pub fn onUpdate(self: *Self) !void {
    clay.setLayoutDimensions(.{
        .w = @floatFromInt(self.window.width),
        .h = @floatFromInt(self.window.height),
    });
    clay.setPointerState(.{ .x = 0, .y = 0 }, false);
    clay.updateScrollContainers(false, .{ .x = 0, .y = 0 }, 0);

    const light_grey: clay.Color = .{ 224, 215, 210, 255 };
    const font = try self.font.components.get(try self.font.default());

    clay.beginLayout();

    // var it = self.element.components.iterator();
    // while (it.next()) |entry| {
    //
    //     // Find parent viewport
    //     var viewport_id: ?nux.ID = null;
    //     while (true) {
    //         const parent_id = try self.node.getParent(entry.id);
    //         if (self.viewport.components.has(parent_id)) {
    //
    //         }
    //     }
    // }

    clay.UI()(.{
        .id = .ID("SideBar"),
        .layout = .{
            .direction = .top_to_bottom,
            .sizing = .{ .w = .grow, .h = .grow },
            .padding = .all(16),
            .child_alignment = .{ .x = .center, .y = .center },
            .child_gap = 16,
        },
        .background_color = light_grey,
    })({
        self.sidebarItemComponent(0, font);
        self.sidebarItemComponent(1, font);
        self.sidebarItemComponent(2, font);
        self.sidebarItemComponent(3, font);
    });
    const commands = clay.endLayout();

    var cb: nux.Graphics.CommandBuffer = .init(self.allocator);
    defer cb.deinit();
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
    try self.gpu.render(&cb);
}
