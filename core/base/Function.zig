const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

pub const ID = struct {
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
        if (@hasDecl(param, "primitive")) {
            tmp[i] = .{
                .name = param.name,
                .typ = param.primitive,
            };
        } else {
            tmp[i] = .{
                .name = param.name,
                .typ = .enumeration,
            };
        }
    }
    const result = tmp;
    return &result;
}

pub const Type = struct {
    name: [:0]const u8,
    params: []const Parameter,
    return_type: ?nux.Primitive.Type,
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
                    var param_count: usize = 0;
                    inline for (fn_params, 0..) |param, i| {
                        if (i == 0) continue;
                        tmp[param_count] = param.type.?;
                        param_count += 1;
                    }
                    const slice: []const type = tmp[0..param_count];
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
                            (try args.next(args, .enumeration)).enumeration,
                        ) orelse return error.InvalidEnumValue;
                    } else {
                        @field(call_args, field_name) = (try args.next(
                            args,
                            params[i - 1].typ,
                        )).into(ParamType);
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

core: *nux.Core,

fn getFunction(self: *Self, module: nux.ModuleID, function: nux.FunctionID) !*Type {
    const mod = try self.core.getModule(module);
    if (function.index >= mod.functions.items.len) {
        return error.InvalidFunctionID;
    }
    return &mod.functions.items[function.index];
}

pub fn count(self: *Self, module: nux.ModuleID) !u32 {
    const mod = try self.core.getModule(module);
    return @intCast(mod.functions.items.len);
}
pub fn getName(self: *Self, module: nux.ModuleID, id: nux.FunctionID) ![]const u8 {
    const func = try self.getFunction(module, id);
    return func.name;
}
pub fn getReturnType(self: *Self, module: nux.ModuleID, id: nux.FunctionID) !nux.Primitive.Type {
    // const func = try self.getFunction(module, id);
    // func.return_type;
    _ = module;
    _ = self;
    _ = id;
    return .bool;
}
