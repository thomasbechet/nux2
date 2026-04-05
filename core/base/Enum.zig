pub const ID = usize;

pub const Value = struct {
    name: [:0]const u8,
    value: u64,
};

pub const Type = struct {
    name: [:0]const u8,
    values: []const Value,
};
