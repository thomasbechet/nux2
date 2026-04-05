const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
pub const ID = u8;

/// Use cases:
/// - Bind property to a widget
/// - Bind property to animation
pub const Ref = struct {
    id: nux.ID,
    component: nux.ComponentID,
    property: nux.PropertyID,
    index: u32 = 0,
};

pub const Type = struct {
    name: []const u8,
    v_get: *const fn (*anyopaque, id: nux.ID) anyerror!nux.Primitive.Value,
    v_set: *const fn (*anyopaque, id: nux.ID, value: nux.Primitive.Value) anyerror!void,

    pub fn init(
        comptime T: type,
        comptime V: type,
        comptime name: []const u8,
        getter: *const fn (*T, id: nux.ID) anyerror!V,
        setter: *const fn (*T, id: nux.ID, value: V) anyerror!void,
    ) Type {
        _ = setter;
        _ = getter;

        const gen = struct {
            fn get(module: *anyopaque, id: nux.ID) anyerror!nux.Primitive.Value {
                _ = module;
                _ = id;
                return undefined;
            }
            fn set(module: *anyopaque, id: nux.ID, value: nux.Primitive.Value) anyerror!void {
                _ = module;
                _ = id;
                _ = value;
            }
        };

        return .{
            .name = name,
            .v_get = gen.get,
            .v_set = gen.set,
        };
    }
};

node: *nux.Node,
component: *nux.Component,

pub fn bind(self: *Self, id: nux.ID, comp: nux.ComponentID, name: []const u8) !Ref {
    const component = try self.component.get(comp);
    for (component.properties(id)) |*p| {
        if (std.mem.eql(u8, p.name, name)) {
            return .{
                .id = id,
                .component = comp,
                .property = p,
            };
        }
    }
    return error.PropertyNotFound;
}
