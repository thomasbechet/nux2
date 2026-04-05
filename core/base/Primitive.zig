const nux = @import("../nux.zig");
const std = @import("std");

pub const MultiArray = std.MultiArrayList(Value);

/// Represents the fundamental value types supported by the system.
///
/// This enum is intentionally kept minimal. It defines only the core set
/// of types required to ensure simple, stable, and predictable data exchange
/// between scripts and function interfaces.
///
/// By limiting the number of types, we avoid unnecessary complexity,
/// reduce conversion overhead, and make interoperability easier across
/// different parts of the system (e.g., scripting layers, modules, and APIs).
///
/// Additional or more specialized types should be built on top of these
/// primitives rather than added here.
pub const Type = enum(u32) {
    bool,
    number,
    vec2,
    vec3,
    vec4,
    mat3,
    mat4,
    string,
    id,
    module,
    function,
    enumeration,
};

pub const Value = union(Type) {
    bool: bool,
    number: f64,
    vec2: nux.Vec2,
    vec3: nux.Vec3,
    vec4: nux.Vec4,
    mat3: nux.Mat3,
    mat4: nux.Mat4,
    string: []const u8,
    id: nux.ID,
    module: nux.ModuleID,
    function: nux.FunctionID,

    fn from(comptime T: type, value: T) Value {
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
        switch (T) {
            else => @compileError("Unsupported type " ++ @typeName(T)),
        }
    }
};

pub const Field = enum(u32) {
    x,
    y,
    z,
    w,
    h,
};
