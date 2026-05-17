const std = @import("std");

pub const VTable = struct {
    /// Return the ram usage is Mb
    /// Return null if not available
    ram_usage: *const fn (*anyopaque) ?f64 = Default.ram_usage,
};

ptr: *anyopaque = undefined,
vtable: *const VTable = &.{},

const Default = struct {
    fn ram_usage(_: *anyopaque) ?f64 {
        return null;
    }
};
