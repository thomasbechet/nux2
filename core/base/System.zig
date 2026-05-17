const nux = @import("../nux.zig");

const Self = @This();

platform: nux.Platform.System,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.platform = core.platform.system;
}

/// Max year 2262 (use i64 in scripts)
pub fn getTimestamp(self: *Self) u64 {
    return self.platform.vtable.timestamp(self.platform.ptr);
}
pub fn getMemoryUsage(self: *Self) f32 {
    if (self.platform.vtable.memory_usage(self.platform.ptr)) |usage| {
        return usage;
    }
    return 0;
}
