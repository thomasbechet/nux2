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
        if (@typeInfo(T) == .@"enum") {
            return .enumeration;
        } else {
            return switch (T) {
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
                nux.Box2 => .box2,
                nux.Box2i => .box2,
                nux.Box3 => .box3,
                nux.Box3i => .box3,
                []const u8 => .string,
                nux.ID => .id,
                nux.ModuleID => .module,
                nux.FunctionID => .function,
                else => @compileError("Unsupported type " ++ @typeName(T)),
            };
        }
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
    enumeration: u64,

    pub fn from(comptime T: type, value: T) Value {
        if (@typeInfo(T) == .@"enum") {
            return .{ .int = @intFromEnum(value) };
        }
        switch (T) {
            bool => return .{ .bool = value },
            u8 => return .{ .int = @intCast(value) },
            i32 => return .{ .int = @intCast(value) },
            u32 => return .{ .int = @intCast(value) },
            i64 => return .{ .int = @intCast(value) },
            u64 => return .{ .int = @intCast(value) },
            f32 => return .{ .real = @floatCast(value) },
            f64 => return .{ .real = @floatCast(value) },
            nux.Vec2 => return .{ .vec2 = value.as(nux.Vec2) },
            nux.Vec2i => return .{ .vec2 = value.as(nux.Vec2) },
            nux.Vec3 => return .{ .vec3 = value.as(nux.Vec3) },
            nux.Vec3i => return .{ .vec3 = value.as(nux.Vec3) },
            nux.Vec4 => return .{ .vec4 = value.as(nux.Vec4) },
            nux.Vec4i => return .{ .vec4 = value.as(nux.Vec4) },
            nux.Quat => return .{ .quat = value },
            []const u8 => return .{ .string = value },
            nux.Color => return .{ .color = value },
            nux.ID => return .{ .id = value },
            nux.ModuleID => return .{ .module = value },
            nux.FunctionID => return .{ .function = value },
            else => @compileError("Unsupported type " ++ @typeName(T)),
        }
    }

    pub fn into(value: Value, comptime T: type) T {
        if (@typeInfo(T) == .@"enum") {
            return .int;
        }
        switch (T) {
            bool => return value.bool,
            u8 => return @intCast(value.int),
            i32 => return @intCast(value.int),
            u32 => return @intCast(value.int),
            i64 => return @intCast(value.int),
            u64 => return @intCast(value.int),
            f32 => return @floatCast(value.real),
            f64 => return @floatCast(value.real),
            nux.Vec2 => return value.vec2.as(nux.Vec2),
            nux.Vec2i => return value.vec2.as(nux.Vec2i),
            nux.Vec3 => return value.vec3.as(nux.Vec3),
            nux.Vec3i => return value.vec3.as(nux.Vec3i),
            nux.Vec4 => return value.vec4.as(nux.Vec4),
            nux.Vec4i => return value.vec4.as(nux.Vec4i),
            nux.Quat => return value.quat,
            []const u8 => return value.string,
            nux.Color => return value.color,
            nux.ID => return value.id,
            nux.ModuleID => return value.module,
            nux.FunctionID => return value.function,
            else => @compileError("Unsupported type " ++ @typeName(T)),
        }
    }
};
