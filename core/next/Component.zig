const nux = @import("../nux.zig");

pub const ComponentField = struct {
    name: []const u8,
    type: nux.Primitive,
};

pub const ComponentType = struct {
    name: []const u8,
    fields: []const ComponentField,

    pub fn getField(self: *ComponentType, name: []const u8) ?*ComponentField {
        _ = self;
        _ = name;
        return null;
    }
};
