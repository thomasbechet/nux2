const nux = @import("../nux.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("clay.h");
});

const Self = @This();

allocator: std.mem.Allocator,
logger: *nux.Logger,

fn errorHandlerFunction(errorData: c.Clay_ErrorData) callconv(.c) void {
    // See the Clay_ErrorData struct for more information
    std.log.err("{s}", .{errorData.errorText.chars});
}

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;

    // Initialize clay
    const memory_size = c.Clay_MinMemorySize();
    const memory = try self.allocator.alloc(u8, memory_size);
    defer self.allocator.free(memory);
    const arena = c.Clay_CreateArenaWithCapacityAndMemory(memory_size, memory.ptr);

    const width = 1000;
    const height = 1000;
    _ = c.Clay_Initialize(arena, .{ .width = width, .height = height }, .{ .errorHandlerFunction = errorHandlerFunction });

    c.Clay_SetLayoutDimensions(.{ .height = height, .width = width });
    c.Clay_SetPointerState(.{ .x = 0, .y = 0 }, false);
    c.Clay_UpdateScrollContainers(false, .{ .x = 0, .y = 0 }, 0);

    c.Clay_BeginLayout();
    const commands = c.Clay_EndLayout();
    self.logger.info("CLAY COMMANDS {d}", .{commands.length});
}
