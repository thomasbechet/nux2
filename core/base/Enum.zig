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

pub fn getValues(comptime T: type) []const Value {
    const decls = @typeInfo(T.Values).@"struct".decls;
    comptime var tmp: [decls.len]Value = undefined;
    inline for (decls, 0..) |decl, i| {
        const value = @field(T.Values, decl.name);
        if (T.is_bitfield) {
            tmp[i] = .{
                .name = value.name,
                .value = @intCast(@as(u32, @bitCast(value.value))),
            };
        } else {
            tmp[i] = .{
                .name = value.name,
                .value = @as(u64, @intFromEnum(value.value)),
            };
        }
    }
    const result = tmp;
    return &result;
}
