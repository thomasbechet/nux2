const nux = @import("../nux.zig");
const std = @import("std");

pub const MultiArray = std.MultiArrayList(Value);

pub const Type = enum(u32) {
    bool,
    u8,
    i32,
    u32,
    f32,
    f64,
    vec2,
    vec2i,
    vec3,
    vec4,
    vec4i,
    quat,
    mat3,
    mat4,
    box2,
    box2i,
    box3,
    box3i,
    string,
    id,
    color,
    module,
    function,
};

pub const Value = union(Type) {
    bool: bool,
    u8: u8,
    i32: i32,
    u32: u32,
    f32: f32,
    f64: f64,
    vec2: nux.Vec2,
    vec2i: nux.Vec2i,
    vec3: nux.Vec3,
    vec4: nux.Vec4,
    vec4i: nux.Vec4i,
    quat: nux.Quat,
    mat3: nux.Mat3,
    mat4: nux.Mat4,
    box2: nux.Box2,
    box2i: nux.Box2i,
    box3: nux.Box3,
    box3i: nux.Box3i,
    string: []const u8,
    id: nux.ID,
    color: nux.Color,
    module: nux.ModuleID,
    function: nux.Function,
    @"enum": nux.Enum,

    pub fn from(comptime T: type, value: T) Value {
        switch (T) {
            bool => return .{ .bool = value },
            u8 => return .{ .number = @floatFromInt(value) },
            i32 => return .{ .number = @floatFromInt(value) },
            u32 => return .{ .number = @floatFromInt(value) },
            i64 => return .{ .number = @floatFromInt(value) },
            u64 => return .{ .number = @floatFromInt(value) },
            f32 => return .{ .number = @floatCast(value) },
            f64 => return .{ .number = @floatCast(value) },
            nux.Vec2 => return .{ .vec2 = value.as(nux.Vec2) },
            nux.Vec2i => return .{ .vec2 = value.as(nux.Vec2) },
            nux.Vec3 => return .{ .vec3 = value.as(nux.Vec3) },
            nux.Vec3i => return .{ .vec3 = value.as(nux.Vec3) },
            nux.Vec4 => return .{ .vec4 = value.as(nux.Vec4) },
            nux.Vec4i => return .{ .vec4 = value.as(nux.Vec4) },
            []const u8 => return .{ .string = value },
            nux.ID => return .{ .id = value },
            nux.ModuleID => return .{ .module = value },
            nux.FunctionID => return .{ .function = value },
            else => @compileError("Unsupported type " ++ @typeName(T)),
        }
    }

    fn into(comptime T: type, value: Value) T {
        _ = value;
        switch (T) {
            else => @compileError("Unsupported type " ++ @typeName(T)),
        }
    }
    pub fn intoEnum(comptime T: type, value: Value) !T {
        std.enums.fromInt(
            T,
            value.number,
        ) orelse return error.InvalidEnumValue;
    }
};
