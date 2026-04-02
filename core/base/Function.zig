const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

const Argument = struct {
    name: []const u8,
    typ: nux.Property.Primitive,
};

const ArgParser = struct {
    nextU8: *const fn (self: *ArgParser) anyerror!u8,
    nextI32: *const fn (self: *ArgParser) anyerror!i32,
    nextU32: *const fn (self: *ArgParser) anyerror!u32,
    nextID: *const fn (self: *ArgParser) anyerror!nux.ID,
    nextVec3: *const fn (self: *ArgParser) anyerror!nux.Vec3,
    nextQuat: *const fn (self: *ArgParser) anyerror!nux.Quat,
    nextString: *const fn (self: *ArgParser) anyerror![]const u8,
};

v_ptr: *anyopaque,
v_call: *const fn (*anyopaque, args: *ArgParser) anyerror!?nux.Property.Value,

pub fn call(self: *Self, args: *ArgParser) !nux.Property.Value {
    return self.v_call(self.v_ptr, args);
}

pub fn wrap(
    comptime T: type,
    comptime method: anytype,
    module: *T,
) Self {
    const Wrapper = struct {
        fn call(ptr: *anyopaque, args: *ArgParser) anyerror!?nux.Property.Value {
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
                const type_info = @typeInfo(ParamType);
                if (type_info == .@"enum") {
                    @field(call_args, field_name) = std.enums.fromInt(
                        ParamType,
                        try args.nextU32(args),
                    ) orelse return error.InvalidEnumValue;
                } else if (type_info == .type) {
                    @field(call_args, field_name) = switch (type_info.type) {
                        u8 => try args.nextU8(args),
                        i32 => try args.nextI32(args),
                        u32 => try args.nextU32(args),
                        nux.ID => try args.nextID(args),
                        nux.Vec3 => try args.nextVec3(args),
                        nux.Quat => try args.nextQuat(args),
                        []const u8 => try args.nextString(args),
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
    return @This(){
        .v_ptr = module,
        .v_call = Wrapper.call,
    };
}
