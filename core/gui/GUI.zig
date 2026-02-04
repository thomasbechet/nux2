const nux = @import("../nux.zig");
const std = @import("std");
const clay = @import("zclay");

const Self = @This();

allocator: std.mem.Allocator,
logger: *nux.Logger,

pub fn measureText(clay_text: []const u8, config: *clay.TextElementConfig, user_data: void) clay.Dimensions {
    _ = config;
    _ = user_data;
    return .{
        .w = @floatFromInt(clay_text.len * 8),
        .h = 8,
    };
}

fn sidebarItemComponent(index: u32) void {
    const sidebar_item_layout: clay.LayoutConfig = .{ .sizing = .{ .w = .grow, .h = .fixed(50) } };
    const orange: clay.Color = .{ 225, 138, 50, 255 };
    clay.UI()(.{
        .id = .IDI("SidebarBlob", index),
        .layout = sidebar_item_layout,
        .background_color = orange,
    })({});
}

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;

    // Initialize clay
    const min_memory_size: u32 = clay.minMemorySize();
    const memory = try self.allocator.alloc(u8, min_memory_size);
    defer self.allocator.free(memory);
    const arena: clay.Arena = clay.createArenaWithCapacityAndMemory(memory);
    _ = clay.initialize(arena, .{ .h = 1000, .w = 1000 }, .{});
    clay.setMeasureTextFunction(void, {}, measureText);

    clay.setLayoutDimensions(.{ .h = 1000, .w = 1000 });
    clay.setPointerState(.{ .x = 0, .y = 0 }, false);
    clay.updateScrollContainers(false, .{ .x = 0, .y = 0 }, 0);

    const light_grey: clay.Color = .{ 224, 215, 210, 255 };

    clay.beginLayout();
    clay.UI()(.{
        .id = .ID("SideBar"),
        .layout = .{
            .direction = .top_to_bottom,
            .sizing = .{ .w = .fixed(300), .h = .grow },
            .padding = .all(16),
            .child_alignment = .{ .x = .center, .y = .top },
            .child_gap = 16,
        },
        .background_color = light_grey,
    })({
        sidebarItemComponent(0);
    });

    const commands = clay.endLayout();
    self.logger.info("CLAY COMMANDS {d}", .{commands.len});

    for (commands) |command| {
        switch (command.command_type) {
            else => {}
        }
    }
}
