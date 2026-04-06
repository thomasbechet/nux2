const nux = @import("../nux.zig");

pub const ID = struct {
    module: nux.ModuleID,
    index: usize,
};

pub const Value = struct {
    name: [:0]const u8,
    value: u64,
};

pub const Type = struct {
    name: [:0]const u8,
    values: []const Value,
};
