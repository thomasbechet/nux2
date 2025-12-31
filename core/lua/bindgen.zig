const std = @import("std");
const Ast = std.zig.Ast;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const FunctionIter = struct {
    alloc: Allocator,
    ast: *const Ast,
    slice: []const Ast.Node.Index,

    const FunctionParam = struct {
        ident: []const u8,
        typ: []const u8,
    };

    const FunctionProto = struct {
        alloc: Allocator,
        name: []const u8,
        params: []const FunctionParam,
        ret: []const u8,

        fn deinit(self: *const @This()) void {
            self.alloc.free(self.params);
        }
    };

    pub fn init(alloc: Allocator, ast: *const Ast) !FunctionIter {
        return .{
            .alloc = alloc,
            .ast = ast,
            .slice = ast.rootDecls(),
        };
    }

    fn parseProto(self: *FunctionIter, idx: Ast.Node.Index) !?FunctionProto {

        // check is function
        const node = self.ast.nodes.get(@intFromEnum(idx));
        switch (node.tag) {
            .fn_decl,
            .fn_proto_multi,
            .fn_proto_simple,
            => {},
            else => {
                return null;
            },
        }

        // parse function
        var buf: [1]Ast.Node.Index = undefined;
        const proto = self.ast.fullFnProto(&buf, idx).?;
        const name = self.ast.tokenSlice(proto.name_token.?);

        // check pub function
        const visib = proto.visib_token orelse return null;
        if (!std.mem.eql(u8, self.ast.tokenSlice(visib), "pub")) {
            return null;
        }

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

        return FunctionProto{
            .alloc = self.alloc,
            .name = name,
            .params = params,
            .ret = return_type,
        };
    }

    pub fn next(self: *FunctionIter) !?FunctionProto {
        var ret: ?FunctionProto = null;
        for (self.slice) |index| {
            self.slice = self.slice[1..];
            if (try self.parseProto(index)) |proto| {
                ret = proto;
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

const Module = struct {
    source: [:0]const u8,
    path: []const u8,
    ast: Ast,
    functions: ArrayList(FunctionIter.FunctionProto),

    fn deinit(self: *Module, alloc: Allocator) void {
        for (self.functions.items) |proto| {
            proto.deinit();
        }
        self.functions.deinit(alloc);
        self.ast.deinit(alloc);
        alloc.free(self.path);
        alloc.free(self.source);
    }
};

const Modules = struct {
    allocator: Allocator,
    modules: ArrayList(Module),
    source: []const u8,

    fn load(alloc: Allocator, modules_path: []const u8) !Modules {
        // parse modules.json
        var buffer: [1024]u8 = undefined;
        const modules_file = try std.fs.cwd().openFile(modules_path, .{});
        defer modules_file.close();
        var modules_reader = modules_file.reader(&buffer);
        const modules_source = try modules_reader.interface.allocRemaining(alloc, .unlimited);
        errdefer alloc.free(modules_source);
        const modules_json = try std.json.parseFromSlice([]ModuleJson, alloc, modules_source, .{});
        defer modules_json.deinit();
        var modules: ArrayList(Module) = try .initCapacity(alloc, modules_json.value.len);
        errdefer modules.deinit(alloc);

        // iter files and generate bindings
        for (modules_json.value) |module| {
            // read file
            const file = try std.fs.cwd().openFile(module.path, .{});
            defer file.close();
            var reader = file.reader(&buffer);
            const source = try reader.interface.allocRemaining(alloc, .unlimited);
            defer alloc.free(source);
            const sourceZ = try alloc.dupeZ(u8, source);
            errdefer alloc.free(sourceZ);
            // parse ast
            var ast = try std.zig.Ast.parse(alloc, sourceZ, .zig);
            errdefer ast.deinit(alloc);
            // parse functions
            var functions = try ArrayList(FunctionIter.FunctionProto).initCapacity(alloc, 32);
            errdefer functions.deinit(alloc);
            var it = try FunctionIter.init(alloc, &ast);
            while (try it.next()) |proto| {
                var ignore = false;
                if (module.ignore) |list| {
                    for (list) |s| {
                        if (std.mem.eql(u8, s, proto.name)) {
                            ignore = true;
                            proto.deinit();
                            break;
                        }
                    }
                }
                if (!ignore) {
                    try functions.append(alloc, proto);
                }
            }
            // add new module
            try modules.append(alloc, .{
                .source = sourceZ,
                .ast = ast,
                .functions = functions,
                .path = try alloc.dupe(u8, module.path),
            });
        }

        return .{
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
    }

    fn print(self: *const Modules) !void {
        for (self.modules.items) |*module| {
            const module_name = std.fs.path.stem(module.path);
            for (module.functions.items) |*function| {
                var func_name = try toSnakeCase(self.allocator, function.name);
                defer func_name.deinit(self.allocator);
                std.log.info("{s}.{s} {s}", .{ module_name, function.name, function.ret });
                for (function.params) |*param| {
                    std.log.info("- {s} {s}", .{ param.ident, param.typ });
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

fn generateBindings(alloc: Allocator, writer: *std.Io.Writer, modules: *const Modules) !void {
    try modules.print();
    try writer.print(
        \\pub fn Bindings(c: anytype) type {{
        \\  return struct {{
    , .{});
    for (modules.modules.items) |*module| {
        const module_name = std.fs.path.stem(module.path);
        try writer.print("const {s} = struct {{", .{module_name});
        for (module.functions.items) |*function| {
            var func_name = try toSnakeCase(alloc, function.name);
            defer func_name.deinit(alloc);
            try writer.print("fn {s}(lua: ?*c.lua_State) callconv(.c) c_int {{", .{function.name});
            try writer.print(
                \\c.lua_pushinteger(lua, 1);
                \\return 1; 
            , .{});
            try writer.print("}}\n", .{});
        }
        try writer.print("}};", .{});
    }

    try writer.print("pub fn openModules(lua: ?*c.lua_State) void {{\n", .{});
    for (modules.modules.items) |*module| {
        const module_name = std.fs.path.stem(module.path);
        try writer.print("c.lua_newtable(lua);\n", .{});
        try writer.print("const {s}_lib: [*]const c.luaL_Reg = &.{{", .{module_name});
        for (module.functions.items) |*function| {
            var func_name = try toSnakeCase(alloc, function.name);
            defer func_name.deinit(alloc);
            try writer.print(".{{ .name = \"{s}\", .func = {s}.{s} }},\n", .{ func_name.items, module_name, function.name });
        }
        try writer.print(".{{ .name = null, .func = null }}, }};\n", .{});
        try writer.print("c.luaL_setfuncs(lua, {s}_lib, 0);\n", .{module_name});
        try writer.print("c.lua_setglobal(lua, \"{s}\");\n", .{module_name});
    }
    try writer.print("}}\n", .{});
    try writer.print("}}; }}", .{});
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
