const std = @import("std");
const nux = @import("../nux.zig");
const clay = @import("zclay");

const Self = @This();

allocator: std.mem.Allocator,
node: *nux.Node,
font: *nux.Font,
window: *nux.Window,
gpu: *nux.GPU,
clay_memory: []u8,

pub fn measureText(text: []const u8, config: *clay.TextElementConfig, _: *Self) clay.Dimensions {
    const font_size: u32 = @intCast(config.font_size);
    var text_width: u32 = 0;
    var max_text_width: u32 = 0;
    var text_height: u32 = font_size;

    const font: *nux.Font.Font = @ptrCast(@alignCast(config.user_data));
    var it = font.iterate(text);
    while (it.next()) |entry| {
        const glyph = entry.glyph;
        if (entry.codepoint != '\n') {
            text_width += glyph.box.w() + 1;
        } else {
            max_text_width = @max(max_text_width, text_width);
            text_width = 0;
            text_height += font_size + @as(u32, @intCast(config.line_height));
        }
    }
    // const letter_spacing: u32 = @intCast(config.letter_spacing);
    const scale_factor = font_size / 8;
    // const spacing_width = letter_spacing * (@as(u32, @floatFromInt(max_byte_counter)) - 1);

    return clay.Dimensions{
        .h = @floatFromInt(text_height),
        .w = @floatFromInt(max_text_width * scale_factor),
    };
}

fn sidebarItemComponent(index: u32, font: *nux.Font.Font) void {
    const sidebar_item_layout: clay.LayoutConfig = .{ .sizing = .{ .w = .grow, .h = .fixed(50) } };
    const orange: clay.Color = .{ 225, 138, 50, 255 };
    clay.UI()(.{
        .id = .IDI("SidebarBlob", index),
        .layout = sidebar_item_layout,
        .background_color = orange,
    })({
        var buf: [256]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buf);
        writer.print("Side Element {d}", .{index}) catch return;
        const text = buf[0..writer.end];
        clay.text(text, .{
            .font_size = 24,
            .user_data = @ptrCast(font),
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
fn convertClayColor(color: [4]f32) [4]f32 {
    return .{
        color[0] / 255,
        color[1] / 255,
        color[2] / 255,
        color[3] / 255,
    };
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
    clay.UI()(.{
        .id = .ID("SideBar"),
        .layout = .{
            .direction = .top_to_bottom,
            .sizing = .{ .w = .fixed(300), .h = .grow },
            .padding = .all(16),
            .child_alignment = .{ .x = .center, .y = .bottom },
            .child_gap = 16,
        },
        .background_color = light_grey,
    })({
        sidebarItemComponent(0, font);
        sidebarItemComponent(1, font);
        sidebarItemComponent(2, font);
        sidebarItemComponent(3, font);
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
                    .color = convertClayColor(command.render_data.rectangle.background_color),
                });
            },
            .border => {},
            .text => {
                const len: usize = @intCast(command.render_data.text.string_contents.length);
                try cb.text(.{
                    .text = command.render_data.text.string_contents.chars[0..len],
                    .pos = box.pos,
                    .scale = command.render_data.text.font_size / 8,
                    .color = convertClayColor(command.render_data.text.text_color),
                });
            },
            .image => {},
            .scissor_start => {},
            .scissor_end => {},
            .custom => {},
        }
    }
    try self.gpu.render(&cb);
}
