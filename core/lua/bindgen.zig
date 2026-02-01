const std = @import("std");
const Ast = std.zig.Ast;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const AstIter = struct {
    alloc: Allocator,
    ast: *const Ast,
    slice: []const Ast.Node.Index,

    const FunctionParam = struct {
        ident: []const u8,
        typ: []const u8,
    };

    const Function = struct {
        alloc: Allocator,
        name: []const u8,
        params: []const FunctionParam,
        ret: []const u8,
        throw_error: bool,

        fn deinit(self: *@This()) void {
            self.alloc.free(self.params);
        }
    };

    const Enum = struct {
        alloc: Allocator,
        name: []const u8,
        typ: []const u8,
        values: std.ArrayList([]const u8),

        fn deinit(self: *@This()) void {
            self.values.deinit(self.alloc);
        }
    };

    const Item = union(enum) { function: Function, @"enum": Enum };

    pub fn init(alloc: Allocator, ast: *const Ast) !AstIter {
        return .{
            .alloc = alloc,
            .ast = ast,
            .slice = ast.rootDecls(),
        };
    }

    fn parse(self: *AstIter, idx: Ast.Node.Index) !?Item {
        const node = self.ast.nodes.get(@intFromEnum(idx));
        // check visibility
        if (node.main_token > 0) {
            const visib = self.ast.tokenSlice(node.main_token - 1);
            if (!std.mem.eql(u8, visib, "pub")) {
                return null;
            }
        }
        // check function and enums
        switch (node.tag) {
            .fn_decl,
            .fn_proto_multi,
            .fn_proto_simple,
            => {
                // parse function
                var buf: [1]Ast.Node.Index = undefined;
                const proto = self.ast.fullFnProto(&buf, idx).?;
                const name = self.ast.tokenSlice(proto.name_token.?);

                // parse params
                var params = try self.alloc.alloc(FunctionParam, proto.ast.params.len);
                errdefer self.alloc.free(params);
                for (proto.ast.params, 0..) |param, i| {
                    const param_node = self.ast.nodes.get(@intFromEnum(param));
                    switch (param_node.tag) {
                        .identifier => {
                            const param_type = self.ast.tokenSlice(param_node.main_token);
                            const param_name = self.ast.tokenSlice(param_node.main_token - 2);
                            params[i] = .{
                                .ident = param_name,
                                .typ = param_type,
                            };
                        },
                        .ptr_type_aligned => {
                            _, const rhs = param_node.data.opt_node_and_node;
                            const ptr_node = self.ast.nodes.get(@intFromEnum(rhs));
                            var ptr_type = self.ast.tokenSlice(ptr_node.main_token);
                            var ptr_name = self.ast.tokenSlice(ptr_node.main_token - 3);

                            // patch for strings parameter
                            if (std.mem.eql(u8, ptr_name, "[") and std.mem.eql(u8, ptr_type, "u8")) {
                                ptr_type = "string";
                                ptr_name = self.ast.tokenSlice(ptr_node.main_token - 5);
                            }

                            params[i] = .{
                                .ident = ptr_name,
                                .typ = ptr_type,
                            };
                        },
                        .field_access => {
                            const l, const r = param_node.data.node_and_token;
                            const ident_node = self.ast.nodes.get(@intFromEnum(l));
                            const ident_name = self.ast.tokenSlice(ident_node.main_token - 2);
                            const field_name = self.ast.tokenSlice(r);
                            params[i] = .{
                                .ident = ident_name,
                                .typ = field_name,
                            };
                        },
                        else => {
                            std.log.err("unhandled arg type: {any}", .{param_node.tag});
                            return error.Unimplemented;
                        },
                    }
                }

                // parse return type
                const ret_token = self.ast.nodes.get(@intFromEnum(proto.ast.return_type)).main_token;
                var return_type = self.ast.tokenSlice(ret_token);
                if (std.mem.eql(u8, return_type, ".")) {
                    return_type = self.ast.tokenSlice(ret_token + 1);
                }
                // patch for strings parameter
                if (std.mem.eql(u8, return_type, "[")) {
                    return_type = "string";
                }

                // find if function throw error
                var throw_error = false;
                var it = ret_token;
                while (true) {
                    const tok = self.ast.tokenSlice(it);
                    if (std.mem.eql(u8, tok, ")")) break;
                    if (std.mem.eql(u8, tok, "!")) {
                        throw_error = true;
                        break;
                    }
                    it -= 1;
                }

                return .{ .function = Function{
                    .alloc = self.alloc,
                    .name = name,
                    .params = params,
                    .ret = return_type,
                    .throw_error = throw_error,
                } };
            },
            .simple_var_decl => {
                // const a: b = c;
                _, const c = node.data.opt_node_and_opt_node;
                const nc = self.ast.nodes.get(@intFromEnum(c));
                switch (nc.tag) {
                    .container_decl, .container_decl_trailing, .container_decl_arg, .container_decl_arg_trailing => {
                        var buffer: [2]Ast.Node.Index = undefined;
                        const decl = self.ast.fullContainerDecl(&buffer, c.unwrap().?).?;
                        const name = self.ast.tokenSlice(node.main_token + 1);
                        var values = try std.ArrayList([]const u8).initCapacity(self.alloc, decl.ast.members.len);
                        errdefer values.deinit(self.alloc);
                        for (decl.ast.members) |member| {
                            const mem = self.ast.nodes.get(@intFromEnum(member));
                            if (mem.tag != .container_field_init) continue;
                            try values.append(self.alloc, self.ast.tokenSlice(mem.main_token));
                        }

                        return .{ .@"enum" = Enum{ .alloc = self.alloc, .name = name, .typ = "test", .values = values } };
                    },
                    else => {},
                }
            },
            else => {
                return null;
            },
        }
        return null;
    }

    pub fn next(self: *AstIter) !?Item {
        var ret: ?Item = null;
        for (self.slice) |index| {
            self.slice = self.slice[1..];
            if (try self.parse(index)) |item| {
                ret = item;
                break;
            }
        }
        return ret;
    }
};

const ModuleJson = struct {
    path: []const u8,
    ignore: ?[][]const u8 = null,
};
const BindingsJson = struct {
    rootpath: []const u8,
    modules: []const ModuleJson,
};

const Module = struct {
    source: [:0]const u8,
    path: []const u8,
    ast: Ast,
    functions: ArrayList(AstIter.Function),
    enums: ArrayList(AstIter.Enum),

    fn deinit(self: *Module, alloc: Allocator) void {
        for (self.functions.items) |*proto| {
            proto.deinit();
        }
        for (self.enums.items) |*enu| {
            enu.deinit();
        }
        self.functions.deinit(alloc);
        self.enums.deinit(alloc);
        self.ast.deinit(alloc);
        alloc.free(self.path);
        alloc.free(self.source);
    }
};

const Modules = struct {
    allocator: Allocator,
    rootpath: []const u8,
    modules: ArrayList(Module),
    source: []const u8,

    fn load(alloc: Allocator, modules_path: []const u8) !Modules {
        var buffer: [1024]u8 = undefined;

        const modules_file = try std.fs.cwd().openFile(modules_path, .{});
        defer modules_file.close();
        var modules_reader = modules_file.reader(&buffer);
        const modules_source = try modules_reader.interface.allocRemaining(alloc, .unlimited);
        errdefer alloc.free(modules_source);
        const bindings_json = try std.json.parseFromSlice(BindingsJson, alloc, modules_source, .{});
        defer bindings_json.deinit();
        var modules: ArrayList(Module) = try .initCapacity(alloc, bindings_json.value.modules.len);
        errdefer modules.deinit(alloc);
        const rootpath = try alloc.dupe(u8, bindings_json.value.rootpath);
        errdefer alloc.free(rootpath);

        // iter files and generate bindings
        for (bindings_json.value.modules) |module| {
            // convert module path to core
            const parts = [_][]const u8{ "core/", module.path };
            const module_path = try std.mem.concat(alloc, u8, &parts);
            defer alloc.free(module_path);
            // read file
            const file = try std.fs.cwd().openFile(module_path, .{});
            defer file.close();
            var reader = file.reader(&buffer);
            const source = try reader.interface.allocRemaining(alloc, .unlimited);
            defer alloc.free(source);
            const sourceZ = try alloc.dupeZ(u8, source);
            errdefer alloc.free(sourceZ);
            // parse ast
            var ast = try std.zig.Ast.parse(alloc, sourceZ, .zig);
            errdefer ast.deinit(alloc);

            // allocate items
            var functions = try ArrayList(AstIter.Function).initCapacity(alloc, 32);
            errdefer functions.deinit(alloc);
            var enums = try ArrayList(AstIter.Enum).initCapacity(alloc, 32);
            errdefer enums.deinit(alloc);

            // filter items
            var it = try AstIter.init(alloc, &ast);
            while (try it.next()) |next| {
                var item = next;
                const name = switch (item) {
                    .function => |func| func.name,
                    .@"enum" => |enu| enu.name,
                };
                var ignore = false;
                for ([_][]const u8{ "init", "deinit", "onEvent" }) |keyword| {
                    if (std.mem.eql(u8, name, keyword)) {
                        ignore = true;
                    }
                }
                if (module.ignore) |ignore_list| {
                    for (ignore_list) |ignore_name| {
                        if (std.mem.eql(u8, ignore_name, name)) {
                            ignore = true;
                            break;
                        }
                    }
                }
                if (!ignore) {
                    switch (item) {
                        .function => |*func| try functions.append(alloc, func.*),
                        .@"enum" => |*enu| try enums.append(alloc, enu.*),
                    }
                } else {
                    switch (item) {
                        .function => |*func| func.deinit(),
                        .@"enum" => |*enu| enu.deinit(),
                    }
                }
            }

            // add new module
            try modules.append(alloc, .{
                .source = sourceZ,
                .ast = ast,
                .functions = functions,
                .enums = enums,
                .path = try alloc.dupe(u8, module.path),
            });
        }

        return .{
            .rootpath = rootpath,
            .allocator = alloc,
            .source = modules_source,
            .modules = modules,
        };
    }

    fn deinit(self: *Modules) void {
        for (self.modules.items) |*module| {
            module.deinit(self.allocator);
        }
        self.modules.deinit(self.allocator);
        self.allocator.free(self.source);
        self.allocator.free(self.rootpath);
    }

    fn print(self: *const Modules) !void {
        for (self.modules.items) |*module| {
            const module_name = std.fs.path.stem(module.path);
            std.log.info("{s}:", .{module_name});
            for (module.functions.items) |*function| {
                const exception = if (function.throw_error)
                    "!"
                else
                    "";
                std.log.info("\t{s}: {s} {s}", .{ function.name, function.ret, exception });
                for (function.params) |*param| {
                    std.log.info("\t\t{s}: {s}", .{ param.ident, param.typ });
                }
            }
            for (module.enums.items) |*enu| {
                std.log.info("\t{s}:", .{enu.name});
                for (enu.values.items) |value| {
                    std.log.info("\t\t{s}", .{value});
                }
            }
        }
    }
};

fn toSnakeCase(alloc: Allocator, s: []const u8) !ArrayList(u8) {
    var out: ArrayList(u8) = try .initCapacity(alloc, s.len);
    for (s, 0..) |c, i| {
        if (std.ascii.isUpper(c)) {
            if (i != 0) {
                try out.append(alloc, '_');
            }
            try out.append(alloc, std.ascii.toLower(c));
        } else {
            try out.append(alloc, c);
        }
    }
    return out;
}

const PrimitiveType = enum {
    void,
    bool,
    u32,
    string,
    NodeID,
    Vec2,
    Vec3,
    Vec4,
    Quat,
};

fn generateBindings(alloc: Allocator, writer: *std.Io.Writer, modules: *const Modules) !void {
    try modules.print();
    try writer.print("const std = @import(\"std\");\n", .{});
    try writer.print("pub fn Bindings(c: anytype, nux: anytype, Lua: anytype) type {{\n", .{});
    try writer.print("\treturn struct {{\n", .{});
    try writer.print(
        \\        fn context(lua: ?*c.lua_State) *@This() {{
        \\            var ud: ?*anyopaque = undefined;
        \\            _ = c.lua_getallocf(lua, &ud);
        \\            const self: *Lua = @ptrCast(@alignCast(ud));
        \\            return &@field(self, "bindings");
        \\        }}
    , .{});
    for (modules.modules.items, 0..) |*module, module_index| {
        const module_name = std.fs.path.stem(module.path);
        try writer.print("\t\tconst {s} = struct {{\n", .{module_name});
        try writer.print("\t\t\tconst Module = @import(\"{s}/{s}\");\n", .{ modules.rootpath, module.path });
        for (module.functions.items) |*function| {
            try writer.print("\t\t\tfn {s}(lua: ?*c.lua_State) callconv(.c) c_int {{\n", .{function.name});
            // retrieve context
            try writer.print("\t\t\t\tconst self = context(lua);\n", .{});
            for (function.params[1..], 1..) |param, i| { // skip self parameter
                // parameter variable
                const primitive_type = std.meta.stringToEnum(PrimitiveType, param.typ);
                try writer.print("\t\t\t\tconst p{d} = ", .{i});
                if (primitive_type) |typ| {
                    switch (typ) {
                        .bool => try writer.print("c.lua_toboolean(lua, {d});\n", .{i}),
                        .u32 => try writer.print("@as(u32, @intCast(c.luaL_checkinteger(lua, {d})));\n", .{i}),
                        .string => try writer.print("std.mem.span(c.luaL_checklstring(lua, {d}, null));\n", .{i}),
                        .NodeID => try writer.print("@as(nux.NodeID, @bitCast(@as(u32, @intCast(c.luaL_checkinteger(lua, {d})))));\n", .{i}),
                        .Vec2 => try writer.print("Lua.checkUserData(lua, .vec2, {d}).vec2;\n", .{i}),
                        .Vec3 => try writer.print("Lua.checkUserData(lua, .vec3, {d}).vec3;\n", .{i}),
                        .Vec4 => try writer.print("Lua.checkUserData(lua, .vec4, {d}).vec4;\n", .{i}),
                        .Quat => try writer.print("Lua.checkUserData(lua, .quat, {d}).quat;\n", .{i}),
                        else => {},
                    }
                } else { // enum constant
                    try writer.print("std.enums.fromInt(@typeInfo(@TypeOf(Module.{s})).@\"fn\".params[{d}].type.?, c.luaL_checkinteger(lua, {d})) orelse return c.luaL_error(lua, \"invalid enum value\");\n", .{ function.name, i, i });
                }
            }
            // return variable
            var has_return_value = false;
            const ret_primitive_type = std.meta.stringToEnum(PrimitiveType, function.ret);
            if (ret_primitive_type) |typ| {
                if (typ != .void) {
                    has_return_value = true;
                }
            }
            try writer.print("\t\t\t\t", .{});
            if (has_return_value) {
                try writer.print("const ret = ", .{});
            }
            // function call
            try writer.print("self.mod{d}.{s}(", .{ module_index, function.name });
            for (1..function.params.len) |i| {
                try writer.print("p{d}", .{i});
                if (i != function.params.len - 1) {
                    try writer.print(", ", .{});
                }
            }
            // exception
            if (function.throw_error) {
                try writer.print(") catch |err| {{\n", .{});
                try writer.print("\t\t\t\t\treturn c.luaL_error(lua, @errorName(err));\n", .{});
                try writer.print("\t\t\t\t}};\n", .{});
            } else {
                try writer.print(");\n", .{});
            }
            // return value
            if (has_return_value) {
                try writer.print("\t\t\t\t", .{});
                if (ret_primitive_type) |typ| {
                    switch (typ) {
                        .void => {},
                        .bool => try writer.print("c.lua_pushboolean(lua, @intFromBool(ret));\n", .{}),
                        .string => try writer.print("_ = c.lua_pushlstring(lua, ret.ptr, ret.len);\n", .{}),
                        .NodeID => try writer.print("c.lua_pushinteger(lua, @intCast(@as(u32, @bitCast(ret))));\n", .{}),
                        .Vec2 => try writer.print("Lua.pushUserData(lua, .vec2, ret);\n", .{}),
                        .Vec3 => try writer.print("Lua.pushUserData(lua, .vec3, ret);\n", .{}),
                        .Vec4 => try writer.print("Lua.pushUserData(lua, .vec4, ret);\n", .{}),
                        .Quat => try writer.print("Lua.pushUserData(lua, .quat, ret);\n", .{}),
                        else => {
                            try writer.print("c.lua_pushinteger(lua, 1);\n", .{});
                        },
                    }
                } else { // cast enum type to int
                    try writer.print("c.lua_pushinteger(lua, @intFromEnum(ret));\n", .{});
                }
                try writer.print("\t\t\t\treturn 1;\n", .{});
            } else {
                try writer.print("\t\t\t\treturn 0;\n", .{});
            }
            try writer.print("\t\t\t}}\n", .{});
        }
        try writer.print("\t\t}};\n", .{});
    }

    for (modules.modules.items, 0..) |*module, module_index| {
        const module_name = std.fs.path.stem(module.path);
        try writer.print("\t\tmod{d}: *{s}.Module,\n", .{ module_index, module_name });
    }

    try writer.print("\t\tpub fn openModules(self: *@This(), lua: *c.lua_State, core: *const nux.Core) void {{\n", .{});
    for (modules.modules.items, 0..) |*module, module_index| {
        const module_name = std.fs.path.stem(module.path);
        try writer.print("\t\t\tif (core.findModule({s}.Module)) |module| {{\n", .{module_name});
        try writer.print("\t\t\t\tself.mod{d} = module;\n", .{module_index});
        try writer.print("\t\t\t\tc.lua_newtable(lua);\n", .{});
        try writer.print("\t\t\t\tconst {s}_lib: [*]const c.luaL_Reg = &.{{\n", .{module_name});
        for (module.functions.items) |*function| {
            try writer.print("\t\t\t\t\t.{{ .name = \"{s}\", .func = {s}.{s} }},\n", .{ function.name, module_name, function.name });
        }
        try writer.print("\t\t\t\t\t.{{ .name = null, .func = null }},\n", .{});
        try writer.print("\t\t\t\t}};\n", .{});
        try writer.print("\t\t\t\tc.luaL_setfuncs(lua, {s}_lib, 0);\n", .{module_name});
        for (module.enums.items) |enu| {
            var enum_name = try toSnakeCase(alloc, enu.name);
            defer enum_name.deinit(alloc);
            _ = std.ascii.upperString(enum_name.items, enum_name.items);
            for (enu.values.items) |value| {
                // module.ENUM_VALUE
                const value_name = try alloc.dupe(u8, value);
                defer alloc.free(value_name);
                _ = std.ascii.upperString(value_name, value_name);
                try writer.print("\t\t\t\tc.lua_pushinteger(lua, @intFromEnum({s}.Module.{s}.{s}));\n", .{ module_name, enu.name, value });
                try writer.print("\t\t\t\tc.lua_setfield(lua, -2, \"{s}_{s}\");\n", .{ enum_name.items, value_name });
            }
        }
        try writer.print("\t\t\t\tc.lua_setglobal(lua, \"{s}\");\n", .{module_name});
        try writer.print("\t\t\t}}\n", .{});
    }
    try writer.print("\t\t}}\n", .{});
    try writer.print("\t}};\n", .{});
    try writer.print("}}\n", .{});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next(); // skip program
    const output = args.next().?;
    const inputs = args.next().?;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    var buffer: [1024]u8 = undefined;

    // load modules
    var modules: Modules = try .load(alloc, inputs);
    defer modules.deinit();

    // generate bindings
    const out_file = try std.fs.cwd().createFile(output, .{});
    defer out_file.close();
    var writer = out_file.writer(&buffer);
    try generateBindings(alloc, &writer.interface, &modules);
    try writer.interface.flush();
}
