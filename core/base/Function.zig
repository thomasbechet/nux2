const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

pub const ID = struct {
    module: nux.ModuleID,
    index: usize,
};

pub const ArgParser = struct {
    next: *const fn (
        self: *ArgParser,
        typ: nux.Primitive.Type,
    ) anyerror!nux.Primitive.Value,
};

pub const Parameter = struct {
    name: []const u8,
    typ: nux.Primitive.Type,
    @"enum": ?nux.EnumID = null,
};

pub fn getParameters(comptime T: type) []const Parameter {
    const decls = @typeInfo(T).@"struct".decls;

    comptime var tmp: [decls.len]Parameter = undefined;

    inline for (decls, 0..) |decl, i| {
        const param = @field(T, decl.name);
        tmp[i] = .{
            .name = param.name,
            .typ = param.primitive,
        };
    }

    const result = tmp; // <- copy into a const

    return &result;
}

pub const Type = struct {
    name: [:0]const u8,
    params: []const Parameter,
    v_ptr: *anyopaque,
    v_call: *const fn (*anyopaque, args: *ArgParser) anyerror!?nux.Primitive.Value,

    pub fn call(self: *Type, args: *ArgParser) !?nux.Primitive.Value {
        return self.v_call(self.v_ptr, args);
    }

    pub fn wrap(
        name: [:0]const u8,
        comptime T: type,
        comptime method: anytype,
        comptime params: []const Parameter,
        module: *T,
    ) Type {
        const fn_info = @typeInfo(@TypeOf(method)).@"fn";
        const fn_params = fn_info.params;

        const Wrapper = struct {
            fn call(ptr: *anyopaque, args: *ArgParser) anyerror!?nux.Primitive.Value {
                const self: *T = @ptrCast(@alignCast(ptr));

                // Build tuple type (excluding self)
                const ArgTuple = std.meta.Tuple(blk: {
                    var tmp: [fn_params.len - 1]type = undefined;
                    var count: usize = 0;
                    inline for (fn_params, 0..) |param, i| {
                        if (i == 0) continue;
                        tmp[count] = param.type.?;
                        count += 1;
                    }
                    const slice: []const type = tmp[0..count];
                    break :blk slice;
                });

                // Fetch arguments
                var call_args: ArgTuple = undefined;
                inline for (fn_params, 0..) |param, i| {
                    if (i == 0) continue;
                    const ParamType = param.type.?;
                    const field_name = std.fmt.comptimePrint("{d}", .{i - 1});
                    const type_info = @typeInfo(ParamType);
                    if (type_info == .@"enum") {
                        @field(call_args, field_name) = std.enums.fromInt(
                            ParamType,
                            (try args.next(args, .enumeration)).u32,
                        ) orelse return error.InvalidEnumValue;
                    } else {
                        @field(call_args, field_name) = switch (ParamType) {
                            u8 => @intCast((try args.next(args, .int)).int),
                            i32 => @intCast((try args.next(args, .int)).int),
                            u32 => @intCast((try args.next(args, .int)).int),
                            f32 => @floatCast((try args.next(args, .real)).real),
                            f64 => @floatCast((try args.next(args, .real)).real),
                            nux.Vec2i => (try args.next(args, .vec2)).vec2,
                            nux.Vec3 => (try args.next(args, .vec3)).vec3,
                            nux.Quat => (try args.next(args, .quat)).quat,
                            []const u8 => (try args.next(args, .string)).string,
                            nux.Color => (try args.next(args, .color)).color,
                            nux.ID => (try args.next(args, .id)).id,
                            nux.ModuleID => (try args.next(args, .module)).module,
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
                    else => nux.Primitive.Value.from(@TypeOf(value), value),
                };
            }
        };
        return Type{
            .name = name,
            .params = params,
            .v_ptr = module,
            .v_call = Wrapper.call,
        };
    }
};
