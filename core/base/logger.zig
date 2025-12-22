const std = @import("std");

pub const Module = struct {
    pub fn info(
        self: *Module,
        comptime format: []const u8,
        args: anytype,
    ) void {
        _ = self;
        std.log.info(format, args);
    }
};
