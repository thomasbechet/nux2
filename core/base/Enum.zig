const nux = @import("../nux.zig");

const Self = @This();

pub const ID = struct {
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

core: *nux.Core,

fn getEnum(self: *Self, module: nux.ModuleID, enu: nux.EnumID) !*Type {
    const mod = try self.core.getModule(module);
    if (enu.index >= mod.enums.items.len) {
        return error.InvalidEnumID;
    }
    return &mod.enums.items[enu.index];
}

pub fn count(self: *Self, module: nux.ModuleID) !u32 {
    const mod = try self.core.getModule(module);
    return @intCast(mod.enums.items.len);
}
pub fn getName(self: *Self, module: nux.ModuleID, id: nux.EnumID) ![]const u8 {
    const enu = try self.getEnum(module, id);
    return enu.name;
}
pub fn getValueCount(self: *Self, module: nux.ModuleID, id: nux.EnumID) !u32 {
    const enu = try self.getEnum(module, id);
    return @intCast(enu.values.len);
}
pub fn getValueName(self: *Self, module: nux.ModuleID, id: nux.EnumID, index: u32) ![]const u8 {
    const enu = try self.getEnum(module, id);
    if (index >= enu.values.len) {
        return error.InvalidEnumValueID;
    }
    return enu.values[@intCast(index)].name;
}
