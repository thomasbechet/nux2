const std = @import("std");
const Ast = std.zig.Ast;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const PrimitiveType = enum {
    void,
    bool,
    u32,
    f32,
    string,
    ID,
    ComponentID,
    Vec2,
    Vec2i,
    Vec3,
    Vec3i,
    Vec4,
    Vec4i,
    Quat,
    Color,
    Self,
};

const AstIter = struct {
    alloc: Allocator,
    ast: *const Ast,
    slice: []const Ast.Node.Index,
    ignore: ?[][]const u8 = null,

    const Type = struct {
        name: []const u8,
        resolved: ?union(enum) {
            primitive: PrimitiveType,
            @"enum": *Enum,
        } = null,
    };

    const Function = struct {
        const Param = struct {
            ident: []const u8,
            typ: Type,
        };

        alloc: Allocator,
        params: []Param,
        ret: Type,
        throw_error: bool,

        fn deinit(self: *@This()) void {
            self.alloc.free(self.params);
        }
    };

    const Enum = struct {
        alloc: Allocator,
        values: std.ArrayList([]const u8),
        isBitfield: bool,

        fn deinit(self: *@This()) void {
            self.values.deinit(self.alloc);
        }
    };

    const Constant = struct {};

    const Declaration = struct {
        name: []const u8,
        data: union(enum) {
            function: Function,
            @"enum": Enum,
            constant: Constant,
        },

        fn deinit(self: *Declaration) void {
            switch (self.data) {
                .function => |*function| function.deinit(),
                .@"enum" => |*enu| enu.deinit(),
                else => {},
            }
        }
    };

    pub fn init(alloc: Allocator, ast: *const Ast, ignore: ?[][]const u8) !AstIter {
        return .{
            .alloc = alloc,
            .ast = ast,
            .slice = ast.rootDecls(),
            .ignore = ignore,
        };
    }

    fn fullFieldAccessName(
        self: *AstIter,
        node: Ast.Node,
    ) ![]const u8 {
        switch (node.tag) {
            .field_access => {
                const l, const r = node.data.node_and_token;
                // Read most left node
                var left = self.ast.nodes.get(@intFromEnum(l));
                while (left.tag == .field_access) {
                    const ll, _ = left.data.node_and_token;
                    left = self.ast.nodes.get(@intFromEnum(ll));
                }
                const start_tok = left.main_token;
                const end_tok = r;
                const starts = self.ast.tokens.items(.start);
                const start_off = starts[start_tok];
                const end_off =
                    if (end_tok + 1 < starts.len)
                        starts[end_tok + 1]
                    else
                        self.ast.source.len;
                return std.mem.trim(u8, self.ast.source[start_off..end_off], " ");
            },
            .identifier => {
                return std.mem.trim(u8, self.ast.tokenSlice(node.main_token), " ");
            },
            else => return error.Unsupported,
        }
    }

    fn isIgnored(self: *const AstIter, name: []const u8) bool {
        var ignore = false;
        for ([_][]const u8{
            "init",
            "deinit",
            "onEvent",
            "onPreUpdate",
            "onUpdate",
            "onPostUpdate",
            "onRender",
            "Component",
        }) |keyword| {
            if (std.mem.eql(u8, name, keyword)) {
                ignore = true;
            }
        }
        if (self.ignore) |ignore_list| {
            for (ignore_list) |ignore_name| {
                std.debug.print("TEST '{s}' AGAINST '{s}'\n", .{ name, ignore_name });
                if (std.mem.eql(u8, ignore_name, name)) {
                    std.debug.print("IGNORE\n", .{});
                    ignore = true;
                    break;
                }
            }
        }
        return ignore;
    }

    fn parseFunction(self: *AstIter, index: Ast.Node.Index) !Declaration {
        // Parse function
        var buf: [1]Ast.Node.Index = undefined;
        const proto = self.ast.fullFnProto(&buf, index).?;
        const name = self.ast.tokenSlice(proto.name_token.?);

        // Parse params
        var params = try self.alloc.alloc(Function.Param, proto.ast.params.len);
        errdefer self.alloc.free(params);

        // Iterate params
        var param_it = proto.iterate(self.ast);
        var i: usize = 0;
        while (param_it.next()) |param| : (i += 1) {
            const param_name = self.ast.tokenSlice(param.name_token.?);
            if (param.type_expr == null) continue;
            const param_node = self.ast.nodes.get(@intFromEnum(param.type_expr.?));
            switch (param_node.tag) {
                .identifier => {
                    const param_type = self.ast.tokenSlice(param_node.main_token);
                    params[i] = .{
                        .ident = param_name,
                        .typ = .{ .name = param_type },
                    };
                },
                .ptr_type_aligned => {
                    _, const rhs = param_node.data.opt_node_and_node;
                    const ptr_node = self.ast.nodes.get(@intFromEnum(rhs));
                    var ptr_type = self.ast.tokenSlice(ptr_node.main_token);
                    var ptr_name = self.ast.tokenSlice(ptr_node.main_token - 3);

                    // Patch for strings parameter
                    if (std.mem.eql(u8, ptr_name, "[") and std.mem.eql(u8, ptr_type, "u8")) {
                        ptr_type = "string";
                        ptr_name = self.ast.tokenSlice(ptr_node.main_token - 5);
                    }

                    params[i] = .{
                        .ident = ptr_name,
                        .typ = .{ .name = ptr_type },
                    };
                },
                .field_access => {
                    const typ = try self.fullFieldAccessName(param_node);
                    params[i] = .{
                        .ident = param_name,
                        .typ = .{ .name = typ },
                    };
                },
                else => {
                    return error.Unimplemented;
                },
            }
        }

        // Parse return type
        const param_node = self.ast.nodes.get(@intFromEnum(proto.ast.return_type.unwrap().?));
        const ret_token = self.ast.nodes.get(@intFromEnum(proto.ast.return_type)).main_token;
        const return_type = try self.fullFieldAccessName(param_node);

        // Find if function throw error
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

        return .{
            .name = name,
            .data = .{
                .function = .{
                    .alloc = self.alloc,
                    .params = params,
                    .ret = .{ .name = return_type },
                    .throw_error = throw_error,
                },
            },
        };
    }
    fn parseEnum(self: *AstIter, node: Ast.Node) !Declaration {
        // const a: b = c;
        _, const c = node.data.opt_node_and_opt_node;
        const nc = self.ast.nodes.get(@intFromEnum(c));
        switch (nc.tag) {
            .container_decl, .container_decl_trailing, .container_decl_arg, .container_decl_arg_trailing => {
                var buffer: [2]Ast.Node.Index = undefined;
                const decl = self.ast.fullContainerDecl(&buffer, c.unwrap().?).?;
                const name = std.mem.trim(u8, self.ast.tokenSlice(node.main_token + 1), " ");

                // Detect is bitfield
                const isPacked = self.ast.tokenSlice(node.main_token + 3);
                const isStruct = self.ast.tokenSlice(node.main_token + 4);
                const isU32 = self.ast.tokenSlice(node.main_token + 6);
                const isBitfield =
                    std.mem.eql(u8, isPacked, "packed") and std.mem.eql(u8, isStruct, "struct") and std.mem.eql(u8, isU32, "u32");

                // Parse values
                var values = try std.ArrayList([]const u8).initCapacity(self.alloc, decl.ast.members.len);
                errdefer values.deinit(self.alloc);
                for (decl.ast.members) |member| {
                    const mem = self.ast.nodes.get(@intFromEnum(member));
                    if (mem.tag != .container_field_init) continue;
                    const value_name = self.ast.tokenSlice(mem.main_token);
                    if (std.mem.eql(u8, value_name, "_padding")) continue; // Ignore bitfield padding field
                    try values.append(self.alloc, value_name);
                }

                return .{
                    .name = name,
                    .data = .{
                        .@"enum" = .{
                            .alloc = self.alloc,
                            .values = values,
                            .isBitfield = isBitfield,
                        },
                    },
                };
            },
            else => {},
        }
        return error.Unsupported;
    }
    fn parseConstant(self: *AstIter) !Constant {
        _ = self;
        return error.Unsupported;
    }

    pub fn next(self: *AstIter) !?Declaration {
        for (self.slice) |index| {
            self.slice = self.slice[1..];
            const node = self.ast.nodes.get(@intFromEnum(index));

            // Check visibility
            if (node.main_token > 0) {
                const visib = self.ast.tokenSlice(node.main_token - 1);
                if (!std.mem.eql(u8, visib, "pub")) {
                    continue;
                }
            }

            // Try parse declaration
            var decl: ?Declaration = null;
            switch (node.tag) {
                .fn_decl,
                .fn_proto_multi,
                .fn_proto_simple,
                => decl = self.parseFunction(index) catch continue,
                .simple_var_decl => decl = self.parseEnum(node) catch continue,
                else => {},
            }

            if (decl) |*declaration| {
                if (!self.isIgnored(declaration.name)) {
                    return decl;
                } else {
                    declaration.deinit();
                }
            }
        }
        return null;
    }
};

const ModuleJson = struct {
    path: []const u8,
    ignore: ?[][]const u8 = null,
};
const ModulesJson = struct {
    rootpath: []const u8,
    modules: []const ModuleJson,
};

const Module = struct {
    source: [:0]const u8,
    name: []const u8,
    path: []const u8,
    ast: Ast,
    functions: std.StringHashMap(AstIter.Function),
    enums: std.StringHashMap(AstIter.Enum),
    is_component_module: bool,

    fn deinit(self: *Module, alloc: Allocator) void {
        var function_it = self.functions.valueIterator();
        while (function_it.next()) |function| {
            function.deinit();
        }
        var enum_it = self.enums.valueIterator();
        while (enum_it.next()) |enu| {
            enu.deinit();
        }
        self.functions.deinit();
        self.enums.deinit();
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

    fn resolveType(modules: []Module, typ: *AstIter.Type, source: []const u8) !void {

        // Remove nux.
        var name = typ.name;
        if (std.mem.startsWith(u8, typ.name, "nux.")) {
            name = typ.name[4..];
        }

        // Try resolve primitive
        if (std.meta.stringToEnum(PrimitiveType, name)) |primitive| {
            typ.resolved = .{ .primitive = primitive };
            return;
        }

        // Resolve enum declaration
        var parts = std.mem.splitScalar(u8, name, '.');
        if (parts.next()) |module_name| {
            if (parts.next()) |decl_name| {
                for (modules) |*module| {
                    if (std.mem.eql(u8, module.name, module_name)) {
                        if (module.enums.getPtr(decl_name)) |enu| {
                            typ.resolved = .{ .@"enum" = enu };
                            return;
                        }
                    }
                }
            }
        }

        // Not type found
        std.log.err("Unresolved type {s} at {s}", .{ name, source });
        return error.UnresolvedType;
    }

    fn load(alloc: Allocator, modules_path: []const u8) !Modules {
        var buffer: [1024]u8 = undefined;

        // Open yaml file
        const modules_file = try std.fs.cwd().openFile(modules_path, .{});
        defer modules_file.close();
        var modules_reader = modules_file.reader(&buffer);

        // Load yaml file
        const modules_source = try modules_reader.interface.allocRemaining(alloc, .unlimited);
        errdefer alloc.free(modules_source);

        // Parse json
        const modules_json = try std.json.parseFromSlice(ModulesJson, alloc, modules_source, .{});
        defer modules_json.deinit();

        // Allocate arrays
        var modules: ArrayList(Module) = try .initCapacity(alloc, modules_json.value.modules.len);
        errdefer {
            for (modules.items) |*module| {
                module.deinit(alloc);
            }
            modules.deinit(alloc);
        }

        // Copy rootpath
        const rootpath = try alloc.dupe(u8, modules_json.value.rootpath);
        errdefer alloc.free(rootpath);

        // Iter files and generate bindings
        for (modules_json.value.modules) |module| {
            const parts = [_][]const u8{ "core/", module.path };
            const module_path = try std.mem.concat(alloc, u8, &parts);
            defer alloc.free(module_path);

            // Read file
            const file = try std.fs.cwd().openFile(module_path, .{});
            defer file.close();
            var reader = file.reader(&buffer);
            const source = try reader.interface.allocRemaining(alloc, .unlimited);
            defer alloc.free(source);
            const sourceZ = try alloc.dupeZ(u8, source);
            errdefer alloc.free(sourceZ);

            // Parse ast
            var ast = try std.zig.Ast.parse(alloc, sourceZ, .zig);
            errdefer ast.deinit(alloc);

            // Allocate items
            var functions = std.StringHashMap(AstIter.Function).init(alloc);
            errdefer functions.deinit();
            var enums = std.StringHashMap(AstIter.Enum).init(alloc);
            errdefer enums.deinit();

            // Filter items
            var it = try AstIter.init(alloc, &ast, module.ignore);
            while (try it.next()) |next| {
                switch (next.data) {
                    .function => |*func| try functions.putNoClobber(next.name, func.*),
                    .@"enum" => |*enu| try enums.putNoClobber(next.name, enu.*),
                    else => {},
                }
            }

            // Detect component module
            const is_component_module =
                std.mem.containsAtLeast(u8, source, 1, "components: nux.Components(");

            // Add new module
            try modules.append(alloc, .{
                .source = sourceZ,
                .ast = ast,
                .functions = functions,
                .enums = enums,
                .path = try alloc.dupe(u8, module.path),
                .name = std.fs.path.stem(module.path),
                .is_component_module = is_component_module,
            });
        }

        // Resolve types
        var source: [256]u8 = undefined;
        for (modules.items) |*module| {
            var func_it = module.functions.iterator();
            while (func_it.next()) |entry| {
                const func = entry.value_ptr;
                const func_name = entry.key_ptr.*;
                var w = std.Io.Writer.fixed(&source);
                try w.print("{s}:{s}:return", .{ module.name, func_name });
                try resolveType(modules.items, &func.ret, source[0..w.end]);
                for (func.params) |*param| {
                    w = std.Io.Writer.fixed(&source);
                    try w.print("{s}:{s}:{s}", .{ module.name, func_name, param.ident });
                    try resolveType(modules.items, &param.typ, source[0..w.end]);
                }
            }
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
            if (module.is_component_module) {
                std.log.info("{s} (Component):", .{module.name});
            } else {
                std.log.info("{s}:", .{module.name});
            }
            var function_it = module.functions.iterator();
            while (function_it.next()) |*entry| {
                const function = entry.value_ptr;
                const exception = if (function.throw_error)
                    "!"
                else
                    "";
                std.log.info("\t{s}: {s} {s}", .{ entry.key_ptr.*, function.ret.name, exception });
                for (function.params) |*param| {
                    std.log.info("\t\t{s}: {s}", .{ param.ident, param.typ.name });
                }
            }
            var enum_it = module.enums.iterator();
            while (enum_it.next()) |*entry| {
                const enu = entry.value_ptr;
                std.log.info("\t{s} (bitfield: {}):", .{ entry.key_ptr.*, enu.isBitfield });
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

fn toUpperCase(alloc: Allocator, s: []const u8) !ArrayList(u8) {
    const snake_case = try toSnakeCase(alloc, s);
    _ = std.ascii.upperString(snake_case.items, snake_case.items);
    return snake_case;
}

fn generateAPI(alloc: Allocator, writer: *std.Io.Writer, modules: *const Modules) !void {
    try modules.print();
    try writer.print("const nux = @import(\"nux.zig\");\n", .{});
    for (modules.modules.items) |*module| {
        try writer.print("pub const {s} = struct {{\n", .{module.name});
        try writer.print("\tpub const module = nux.{s};\n", .{module.name});
        try writer.print("\tpub const is_component_module = {};\n", .{module.is_component_module});
        try writer.print("\tpub const Enums = struct {{\n", .{});
        var enum_it = module.enums.iterator();
        while (enum_it.next()) |enu| {
            try writer.print("\t\tpub const {s} = struct {{\n", .{enu.key_ptr.*});
            try writer.print("\t\t\tpub const name = \"{s}\";\n", .{enu.key_ptr.*});
            try writer.print("\t\t\tpub const is_bitfield = {};\n", .{enu.value_ptr.isBitfield});
            try writer.print("\t\t\tpub const Values = struct {{\n", .{});
            for (enu.value_ptr.values.items) |value| {
                var value_upper_case = try toUpperCase(alloc, value);
                defer value_upper_case.deinit(alloc);
                try writer.print("\t\t\t\tpub const {s} = struct {{\n", .{value_upper_case.items});
                try writer.print("\t\t\t\t\tpub const name = \"{s}\";\n", .{value_upper_case.items});
                try writer.print("\t\t\t\t\tpub const value = nux.{s}.{s}.{s};\n", .{
                    module.name,
                    enu.key_ptr.*,
                    value,
                });
                try writer.print("\t\t\t\t}};\n", .{});
            }
            try writer.print("\t\t\t}};\n", .{});
            try writer.print("\t\t}};\n", .{});
        }
        try writer.print("\t}};\n", .{});
        try writer.print("\tpub const Functions = struct {{\n", .{});
        var function_it = module.functions.iterator();
        while (function_it.next()) |function| {
            try writer.print("\t\tpub const {s} = struct {{\n", .{function.key_ptr.*});
            try writer.print("\t\t\tpub const name = \"{s}\";\n", .{function.key_ptr.*});
            try writer.print("\t\t\tpub const function = nux.{s}.{s};\n", .{
                module.name,
                function.key_ptr.*,
            });
            try writer.print("\t\t}};\n", .{});
        }
        try writer.print("\t}};\n", .{});
        try writer.print("\tpub const Properties = struct {{\n", .{});

        // Generate properties
        function_it = module.functions.iterator();

        // map: property name -> { getter?, setter? }
        var props = std.StringHashMap(struct {
            getter: ?[]const u8 = null,
            setter: ?[]const u8 = null,
        }).init(alloc);
        defer props.deinit();

        // First pass: collect
        while (function_it.next()) |function| {
            const name = function.key_ptr.*;

            if (std.mem.startsWith(u8, name, "get") or
                std.mem.startsWith(u8, name, "set"))
            {
                const is_get = std.mem.startsWith(u8, name, "get");
                const prop_name = name[3..];

                var entry = try props.getOrPut(prop_name);
                if (!entry.found_existing) {
                    entry.value_ptr.* = .{};
                }

                if (is_get) {
                    entry.value_ptr.getter = name;
                } else {
                    entry.value_ptr.setter = name;
                }
            }
        }

        // Second pass: generate
        var it = props.iterator();
        while (it.next()) |entry| {
            const prop = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            try writer.print("\t\tpub const {s} = struct {{\n", .{prop});

            if (value.getter) |g| {
                try writer.print("\t\t\tpub const name = {s}.Functions.{s}.Name[3..];\n", .{
                    module.name,
                    g,
                });
                try writer.print("\t\t\tpub const getter = nux.{s}.{s};\n", .{
                    module.name,
                    g,
                });
            }

            if (value.setter) |s| {
                try writer.print("\t\t\tpub const setter = nux.{s}.{s};\n", .{
                    module.name,
                    s,
                });
            }

            try writer.print("\t\t}};\n", .{});
        }

        try writer.print("\t}};\n", .{});
        try writer.print("}};\n", .{});
    }
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
    try modules.print();

    // generate bindings
    const out_file = try std.fs.cwd().createFile(output, .{});
    defer out_file.close();
    var writer = out_file.writer(&buffer);
    try generateAPI(alloc, &writer.interface, &modules);
    try writer.interface.flush();
}
