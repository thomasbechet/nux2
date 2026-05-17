const std = @import("std");

pub const VTable = struct {
    // Return the unix timestamp in nanoseconds
    timestamp: *const fn (*anyopaque) u64 = Default.timestamp,

    /// Return the memory usage is MegaBytes or null if unavailable
    memory_usage: *const fn (*anyopaque) ?f32 = Default.memoryUsage,
};

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

const Default = struct {
    fn timestamp(_: *anyopaque) u64 {
        return 0;
    }
    fn memoryUsage(_: *anyopaque) ?f32 {
        return null;
    }
};
