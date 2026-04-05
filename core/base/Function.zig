const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

const Argument = struct {
    name: []const u8,
    typ: nux.Property.Primitive,
};

pub const ArgParser = struct {
    next: *const fn (
        self: *ArgParser,
        typ: nux.Primitive.Type,
    ) anyerror!nux.Primitive.Value,
};

pub const Function = struct {
    name: [:0]const u8,
    v_ptr: *anyopaque,
    v_call: *const fn (*anyopaque, args: *ArgParser) anyerror!?nux.Primitive.Value,

    pub fn call(self: *Function, args: *ArgParser) !?nux.Primitive.Value {
        return self.v_call(self.v_ptr, args);
    }

    pub fn wrap(
        name: [:0]const u8,
        comptime T: type,
        comptime method: anytype,
        module: *T,
    ) Function {
        const Wrapper = struct {
            fn call(ptr: *anyopaque, args: *ArgParser) anyerror!?nux.Primitive.Value {
                const self: *T = @ptrCast(@alignCast(ptr));
                const fn_info = @typeInfo(@TypeOf(method)).@"fn";
                const params = fn_info.params;

                // Build tuple type (excluding self)
                const ArgTuple = std.meta.Tuple(blk: {
                    var tmp: [params.len - 1]type = undefined;
                    var count: usize = 0;
                    inline for (params, 0..) |param, i| {
                        if (i == 0) continue;
                        tmp[count] = param.type.?;
                        count += 1;
                    }
                    const slice: []const type = tmp[0..count];
                    break :blk slice;
                });

                // Fetch arguments
                var call_args: ArgTuple = undefined;
                inline for (params, 0..) |param, i| {
                    if (i == 0) continue;
                    const ParamType = param.type.?;
                    const field_name = std.fmt.comptimePrint("{d}", .{i - 1});
                    @compileLog(field_name);
                    const type_info = @typeInfo(ParamType);
                    if (type_info == .@"enum") {
                        @field(call_args, field_name) = std.enums.fromInt(
                            ParamType,
                            (try args.next(args, .u32)).u32,
                        ) orelse return error.InvalidEnumValue;
                    } else {
                        @field(call_args, field_name) = switch (ParamType) {
                            u8 => (try args.next(args, .u32)).u32,
                            i32 => (try args.next(args, .u32)).u32,
                            u32 => (try args.next(args, .u32)).u32,
                            nux.ID => (try args.next(args, .id)).id,
                            nux.Vec2i => (try args.next(args)).vec2,
                            nux.Vec3 => (try args.next(args)).vec3,
                            nux.Quat => (try args.next(args)).quat,
                            []const u8 => (try args.next(args, .string)).string,
                            nux.Color => (try args.next(args, .color)).color,
                            else => {
                                @compileError("Unsupported argument type " ++ @typeName(ParamType));
                            },
                        };
                    }
                }

                // Call function
                const ret = @call(.auto, method, .{self} ++ call_args);

                // Return value
                const RetType = @TypeOf(ret);
                const value = switch (@typeInfo(RetType)) {
                    .error_union => try ret,
                    else => ret,
                };
                return switch (@TypeOf(value)) {
                    void => null,
                    bool => .{ .bool = value },
                    nux.ID => .{ .id = value },
                    nux.Vec3 => .{ .vec3 = value },
                    nux.Quat => .{ .quat = value },
                    else => @compileError("Unsupported return type " ++ @typeName(@TypeOf(value))),
                };
            }
        };
        return Function{
            .name = name,
            .v_ptr = module,
            .v_call = Wrapper.call,
        };
    }
};
