const nux = @import("../nux.zig");
const std = @import("std");
const c = @cImport({
    @cDefine("CLAY_IMPLEMENTATION", "");
    @cInclude("clay.h");
});

const Self = @This();

allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;

    // Initialize clay
    // const min_memory = c.Clay_MinMemorySize();
    // c.Clay_CreateArenaWithCapacityAndMemory
}
