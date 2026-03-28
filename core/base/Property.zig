const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
pub const ID = u8;

pub const Value = union(enum) {
    id: nux.ID,
    vec2: nux.Vec2,
    vec3: nux.Vec3,
    vec4: nux.Vec4,
    quat: nux.Quat,
};

pub const Ref = struct {
    id: nux.ID,
    component: nux.ComponentID,
    property: nux.PropertyID,
};

pub const Type = struct {
    name: []const u8,
    v_get: *const fn (*anyopaque, id: nux.ID) anyerror!Value,
    v_set: *const fn (*anyopaque, id: nux.ID, value: Value) anyerror!void,

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
            fn get(module: *anyopaque, id: nux.ID) anyerror!Value {
                _ = module;
                _ = id;
                return undefined;
            }
            fn set(module: *anyopaque, id: nux.ID, value: Value) anyerror!void {
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

    // pub fn field(
    //     comptime T: type,
    //     f: anytype,
    // ) Property {
    //     _ = T;
    //     _ = V;
    //     _ = f;
    //     return .{
    //         .name = "test",
    //     };
    // }
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
