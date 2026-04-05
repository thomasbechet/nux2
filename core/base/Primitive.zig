const nux = @import("../nux.zig");
const std = @import("std");

pub const MultiArray = std.MultiArrayList(Value);

pub const Type = enum(u32) {
    bool,
    i32,
    f32,
    vec2,
    vec2i,
    vec3,
    vec3i,
    vec4,
    vec4i,
    quat,
    mat3,
    mat4,
    box2,
    box2i,
    box3,
    box3i,
    color,
    string,
    id,
};

pub const Field = enum(u32) {
    x,
    y,
    z,
    w,
    h,
};

pub const Value = union(Type) {
    bool: bool,
    i32: i32,
    f32: f32,
    vec2: nux.Vec2,
    vec2i: nux.Vec2i,
    vec3: nux.Vec3,
    vec3i: nux.Vec3i,
    vec4: nux.Vec4,
    vec4i: nux.Vec4i,
    quat: nux.Quat,
    mat3: nux.Mat3,
    mat4: nux.Mat4,
    box2: nux.Box2,
    box2i: nux.Box2i,
    box3: nux.Box3,
    box3i: nux.Box3i,
    color: nux.Color,
    string: []const u8,
    id: nux.ID,
};
