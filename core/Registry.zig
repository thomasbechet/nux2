const std = @import("std");
const Core = @import("Core.nux");

const ID = usize;
const EnumerationID = usize;
const PropertyID = usize;
const ModuleID = usize;
const FunctionID = usize;

const Self = @This();

const objects_field = "objects";

const Type = enum {
    bool,
    u32,
    f32,
    vec3,
    quat,
    id,
    object,
    property,
    enumeration,
    function,
    module,
    type,

    fn fromPrimitive(comptime T: type) Type {
        return switch (T) {
            bool => .bool,
            u32 => .u32,
            f32 => .f32,
            [3]f32 => .vec3,
            ID => .id,
            else => @compileError("Unsupported primitive " ++ @typeName(T)),
        };
    }

    fn toPrimitive(comptime typ: Type) type {
        return switch (typ) {
            .bool => bool,
            .u32 => u32,
            .f32 => f32,
            .vec3 => [3]f32,
            .quat => [4]f32,
            .id => ID,
            .module => ModuleID,
            .property => PropertyID,
            .enumeration => EnumerationID,
            .function => FunctionID,
            .type => TypeValue,
        };
    }
};

const TypeValue = union(enum) {
    type: Type,
    enumeration: EnumerationID,
    function: FunctionID,
    module: ModuleID,
};

fn MakeSingleValue() type {
    const enum_fields = std.meta.fields(Type);
    var union_fields: [enum_fields.len]std.builtin.Type.UnionField = undefined;

    inline for (enum_fields, 0..) |field, i| {
        const tag = @field(Type, field.name);
        union_fields[i] = .{
            .name = field.name,
            .type = Type.toPrimitive(tag),
            .alignment = @alignOf(Type.toPrimitive(tag)),
        };
    }

    return @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = Type,
            .fields = &union_fields,
            .decls = &.{},
        },
    });
}

fn MakeSliceValue() type {
    const enum_fields = std.meta.fields(Type);
    var union_fields: [enum_fields.len]std.builtin.Type.UnionField = undefined;

    inline for (enum_fields, 0..) |field, i| {
        const tag = @field(Type, field.name);
        const T = Type.toPrimitive(tag);
        union_fields[i] = .{
            .name = field.name,
            .type = []T,
            .alignment = @alignOf([]T),
        };
    }

    return @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = Type,
            .fields = &union_fields,
            .decls = &.{},
        },
    });
}

fn MakeArrayListValue() type {
    comptime var fields: [@typeInfo(Type).@"enum".fields.len]std.builtin.Type.UnionField = undefined;

    inline for (@typeInfo(Type).@"enum".fields, 0..) |field, i| {
        const tag = @field(Type, field.name);
        fields[i] = .{
            .name = field.name,
            .type = std.ArrayList(Type.toPrimitive(tag)),
            .alignment = @alignOf(std.ArrayList(Type.toPrimitive(tag))),
        };
    }

    const UnionType = @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = Type,
            .fields = &fields,
            .decls = &.{},
        },
    });

    return struct {
        union_value: UnionType,

        pub fn initCapacity(
            comptime tag: Type,
            allocator: std.mem.Allocator,
            capacity: usize,
        ) !@This() {
            const T = std.ArrayList(Type.toPrimitive(tag));
            return .{
                .union_value = @unionInit(
                    UnionType,
                    @tagName(tag),
                    try T.initCapacity(allocator, capacity),
                ),
            };
        }

        pub fn initEmpty(comptime tag: Type) @This() {
            const T = std.ArrayList(Type.toPrimitive(tag));
            return .{
                .union_value = @unionInit(
                    UnionType,
                    @tagName(tag),
                    T.empty,
                ),
            };
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            switch (self.union_value) {
                inline else => |*list| list.deinit(allocator),
            }
        }

        pub fn get(self: *const @This(), index: usize) ?SingleValue {
            switch (self.union_value) {
                inline else => |list, tag| {
                    if (index >= list.items.len) return null;

                    return switch (tag) {
                        inline else => @unionInit(
                            SingleValue,
                            @tagName(tag),
                            list.items[index],
                        ),
                    };
                },
            }
        }
    };
}

pub fn shortTypeName(comptime T: type) []const u8 {
    var iter = std.mem.splitBackwardsScalar(u8, @typeName(T), '.');
    return iter.first();
}

const SingleValue = MakeSingleValue();
const SliceValue = MakeSliceValue();
const ArrayListValue = MakeArrayListValue();

const Enumeration = struct {
    name: []const u8,
    names: std.ArrayList([]const u8),
    values: ArrayListValue,
};

const Property = struct {
    name: []const u8,
    type: TypeValue,
};

const Parameter = struct {
    name: []const u8,
    type: TypeValue,
};

const Function = struct {
    name: []const u8,
    return_type: ?Type,
    parameters: std.ArrayList(Parameter),
};

const Module = struct {
    name: []const u8,
    functions: std.ArrayList(Function),
    enumerations: std.ArrayList(Enumeration),
    properties: std.ArrayList(Property),
    v_ptr: *anyopaque,
    v_module: struct {
        init: *const fn (*anyopaque, core: *Core) anyerror!void,
        deinit: *const fn (*anyopaque) void,
        start: *const fn (*anyopaque) anyerror!void,
        stop: *const fn (*anyopaque) void,
        destroy: *const fn (*anyopaque, std.mem.Allocator) void,
    },
    v_object: ?struct {
        init: *const fn (
            pointer: *anyopaque,
            node: *nux.Node,
            allocator: std.mem.Allocator,
            module_id: nux.ModuleID,
        ) anyerror!void,
        deinit: *const fn (*anyopaque) void,
        add: *const fn (*anyopaque, id: ID) anyerror!void,
        remove: *const fn (*anyopaque, id: ID) void,
        has: *const fn (*anyopaque, id: ID) bool,
        // load: *const fn (*anyopaque, id: ID, reader: *nux.Reader) anyerror!void,
        // save: *const fn (*anyopaque, id: ID, writer: *nux.Writer) anyerror!void,
    },
};

allocator: std.mem.Allocator,
modules: std.ArrayList(Module),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .enumerations = .empty,
        .modules = .empty,
    };
}
pub fn deinit(self: *Self) void {
    for (self.enumerations.items) |*enumeration| {
        enumeration.names.deinit(self.allocator);
        enumeration.values.deinit(self.allocator);
    }
    self.enumerations.deinit(self.allocator);
    for (self.objects.items) |*component| {
        component.properties.deinit(self.allocator);
    }
    self.objects.deinit(self.allocator);
    for (self.modules.items) |*module| {
        for (module.functions.items) |*function| {
            function.parameters.deinit(self.allocator);
        }
        module.functions.deinit(self.allocator);
        module.properties.deinit(self.allocator);
    }
    self.modules.deinit(self.allocator);
}

fn findEnumeration(self: *const Self, name: []const u8) ?EnumerationID {
    for (self.enumerations.items, 0..) |enumeration, index| {
        if (std.mem.eql(u8, enumeration.name, name)) {
            return index;
        }
    }
    return null;
}

fn findModule(self: *const Self, name: []const u8) ?ModuleID {
    for (self.modules.items, 0..) |module, index| {
        if (std.mem.eql(u8, module.name, name)) {
            return index;
        }
    }
    return null;
}

fn getType(self: *const Self, comptime T: type) !TypeValue {
    return switch (@typeInfo(T)) {
        .@"enum" => .{
            .enumeration = self.findEnumeration(shortTypeName(T)) orelse return error.EnumerationNotFound,
        },
        else => return .{ .type = Type.fromPrimitive(T) },
    };
}

fn getModule(self: *Self, comptime M: type) !*Module {
    const name = shortTypeName(M);
    if (self.findModule(name)) |id| {
        return &self.modules.items[id];
    }
    const module = try self.modules.addOne(self.allocator);
    module.* = .{
        .name = name,
        .functions = .empty,
        .properties = .empty,
        .enumerations = .empty,
    };
    return module;
}

pub fn dump(self: *Self) void {

    // Enumerations
    for (self.enumerations.items) |enumeration| {
        std.log.info("enumeration {s}", .{enumeration.name});

        // Values
        for (enumeration.names.items, 0..) |name, index| {
            std.log.info("   value {s} {any}", .{ name, enumeration.values.get(index) });
        }
    }

    // Components
    for (self.objects.items) |object| {
        std.log.info("object {s}", .{object.name});

        // Properties
        for (object.properties.items) |property| {
            std.log.info("   property {s} {}", .{ property.name, property.type });
        }
    }

    // Modules
    for (self.modules.items) |module| {
        std.log.info("module {s}", .{module.name});

        // Functions
        for (module.functions.items) |function| {
            std.log.info("   function {s} {any}", .{ function.name, function.return_type });
            // Parameters
            for (function.parameters.items) |parameter| {
                std.log.info("      param {s} {any}", .{ parameter.name, parameter.type });
            }
        }
    }
}

pub fn addEnum(
    self: *Self,
    M: type,
    T: type,
) !void {
    const module = try self.getModule(M);
    const tag_type: Type =
        switch (@typeInfo(@typeInfo(T).@"enum".tag_type)) {
            .comptime_int => .u32,
            .comptime_float => .f32,
            .int => .u32,
            .float => .f32,
            else => @compileError("Unsupported union type " ++ @typeName(T)),
        };
    const fields = @typeInfo(T).@"enum".fields;
    var names: std.ArrayList([]const u8) = try .initCapacity(self.allocator, fields.len);
    errdefer names.deinit(self.allocator);
    var values: ArrayListValue = try .initCapacity(tag_type, self.allocator, fields.len);
    errdefer values.deinit(self.allocator);
    inline for (fields) |field| {
        names.appendAssumeCapacity(field.name);
        @field(values.union_value, @tagName(tag_type)).appendAssumeCapacity(field.value);
    }
    try module.enumerations.append(self.allocator, .{
        .name = shortTypeName(T),
        .names = names,
        .values = values,
    });
}

pub fn addModule(self: *Self, comptime M: type) !void {
    if (@hasField(M, objects_field)) {}
}

pub fn addFunction(
    self: *Self,
    comptime M: type,
    comptime F: anytype,
) !void {
    const module = try self.getModule(M);
}

pub fn addProperty(
    self: *Self,
    comptime M: type,
    comptime F: anytype,
) !void {
    if (!@hasField(M, objects_field)) {
        @compileError(@typeName(M) ++ " is not an object module");
    }

    const module = try self.getModule(M);
}

pub fn registerObject(
    self: *Self,
    T: type,
    comptime properties: anytype,
) !void {
    const fields = @typeInfo(@TypeOf(properties)).@"struct".fields;
    var props: std.ArrayList(Property) = try .initCapacity(self.allocator, fields.len);
    errdefer props.deinit(self.allocator);

    // Iterate properties
    inline for (fields) |field| {
        const field_type = @FieldType(T, field.name);
        try props.append(self.allocator, .{
            .name = field.name,
            .type = try self.getType(field_type),
        });
    }

    try self.objects.append(self.allocator, .{
        .name = shortTypeName(T),
        .properties = props,
    });
}

pub fn registerModule(
    self: *Self,
    T: type,
    comptime functions: anytype,
) !void {
    const fields = @typeInfo(@TypeOf(functions)).@"struct".fields;
    var funcs: std.ArrayList(Function) = try .initCapacity(self.allocator, fields.len);
    errdefer funcs.deinit(self.allocator);

    // Iterate properties
    inline for (fields) |field| {

        // Return type
        const func_type = @TypeOf(@field(T, field.name));
        var return_type: ?Type = null;
        if (@typeInfo(func_type).@"fn".return_type) |typ| {
            const RetType = switch (@typeInfo(typ)) {
                .error_union => |error_union| error_union.payload,
                else => typ,
            };
            if (@typeInfo(RetType) != .void) {
                return_type = .fromPrimitive(RetType);
            }
        }

        // Parameters
        const params = @typeInfo(func_type).@"fn".params;
        var parameters: std.ArrayList(Parameter) = try .initCapacity(self.allocator, params.len);
        errdefer parameters.deinit(self.allocator);
        inline for (params[1..]) |param| {
            if (param.type) |param_type| {
                // const ParamType = @typeInfo(param_type);
                parameters.appendAssumeCapacity(.{
                    .name = "",
                    .type = try self.getType(param_type),
                });
            }
        }

        // Append function
        try funcs.append(self.allocator, .{
            .name = field.name,
            .return_type = return_type,
            .parameters = parameters,
        });
    }

    try self.modules.append(self.allocator, .{
        .name = shortTypeName(T),
        .functions = funcs,
    });
}

test "registry" {
    const MyObject = struct {
        position: [3]f32,
        scale: [3]f32,
    };

    const MyEnum = enum {
        a,
        b,
        c,
    };

    const MyModule = struct {
        fn loadTexture(self: *@This()) !void {
            _ = self;
        }
        fn computeValue(self: *@This(), param: f32) u32 {
            _ = self;
            _ = param;
            return 0;
        }
        fn getComponentIndex(self: *@This(), comp: MyEnum) !u32 {
            _ = self;
            _ = comp;
            return 0;
        }
    };

    std.testing.log_level = .debug;
    var registry = Self.init(std.testing.allocator);
    defer registry.deinit();
    try registry.addEnum(Type);
    try registry.addEnum(MyEnum);
    try registry.registerObject(MyObject, .{
        .position = .{},
        .scale = .{},
    });
    try registry.registerModule(MyModule, .{
        .loadTexture = .{},
        .computeValue = .{},
        .getComponentIndex = .{},
    });
    registry.dump();
}

test "value" {
    std.testing.log_level = .debug;
    const value: SingleValue = .{ .vec3 = .{ 1, 2, 3 } };
    std.log.info("{}", .{value});
}

test "slice" {
    std.testing.log_level = .debug;
    var data = [_]u32{ 0, 1 };
    const slice: SliceValue = .{ .id = &data };
    std.log.info("{}", .{slice});
}

test "arraylist" {
    std.testing.log_level = .debug;
    const allocator = std.testing.allocator;
    var array = ArrayListValue.initEmpty(.u32);
    defer array.deinit(allocator);
    std.log.info("{}", .{array});
}
