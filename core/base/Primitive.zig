const nux = @import("../nux.zig");
const std = @import("std");

pub const MultiArray = std.MultiArrayList(Value);

pub const Type = enum(u32) {
    bool,
    int,
    real,
    vec2,
    vec3,
    vec4,
    quat,
    mat3,
    mat4,
    box2,
    box3,
    string,
    color,
    id,
    module,
    function,
    enumeration,

    fn fromType(comptime T: type) Type {
        return switch(T) {
            bool => .bool, 
            u8 => .int,
            i32 => .int,
            u32 => .int,
            i64 => .int,
            u64 => .int,
            f32 => .real,
            f64 => .real,
            nux.Vec2 => .vec2,
            nux.Vec2i => .vec2,
            nux.Vec3 => .vec3,
            nux.Vec3i => .vec3,
            nux.Vec4 => .vec4,
            nux.Vec4i => .vec4,
            nux.Quat => .quat,
            []const u8 => .string,
            nux.ID => .id,
            nux.ModuleID => .module,
            nux.FunctionID => .function,
            nux.EnumID => .enumeration,
            else => @compileError("Unsupported type " ++ @typeName(T)),
        };
    }
};

pub const Value = union(Type) {
    bool: bool,
    int: i64,
    real: f64,
    vec2: nux.Vec2,
    vec3: nux.Vec3,
    vec4: nux.Vec4,
    quat: nux.Quat,
    mat3: nux.Mat3,
    mat4: nux.Mat4,
    box2: nux.Box2,
    box3: nux.Box3,
    string: []const u8,
    color: nux.Color,
    id: nux.ID,
    module: nux.ModuleID,
    function: nux.FunctionID,
    enumeration: nux.EnumID,

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
            nux.Quat => return .{ .quat = value },
            []const u8 => return .{ .string = value },
            nux.ID => return .{ .id = value },
            nux.ModuleID => return .{ .module = value },
            nux.FunctionID => return .{ .function = value },
            nux.EnumID => return .{ .enumeration = value },
            else => @compileError("Unsupported type " ++ @typeName(T)),
        }
    }
};
