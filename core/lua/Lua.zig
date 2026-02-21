const std = @import("std");
const nux = @import("../nux.zig");
const Bindings = @import("bindings.zig").Bindings;

pub const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

const Self = @This();

const UserData = union(enum) {
    const Field = enum { x, y, z, w, normal, position };
    vec2: nux.Vec2,
    vec3: nux.Vec3,
    vec4: nux.Vec4,
    quat: nux.Quat,
};

const Error = error{
    NewState,
    LuaSyntax,
    OutOfMemory,
    LuaRuntime,
    LuaMsgHandler,
};

pub const LuaModule = struct {
    ref: c_int = 0,
    signals: std.ArrayList(nux.ID) = .empty,
};

allocator: std.mem.Allocator,
logger: *nux.Logger,
file: *nux.File,
node: *nux.Node,
L: *c.lua_State,
bindings: Bindings(c, nux, @This()),

export fn lua_print(ud: *anyopaque, s: [*c]const u8) callconv(.c) void {
    const self: *Self = @ptrCast(@alignCast(ud));
    const str: [*:0]const u8 = std.mem.span(s);
    self.logger.info("{s}", .{str});
}
export fn lua_printerror(ud: *anyopaque, s: [*c]const u8) callconv(.c) void {
    const self: *Self = @ptrCast(@alignCast(ud));
    const str: [*:0]const u8 = std.mem.span(s);
    self.logger.err("{s}", .{str});
}

fn loadString(self: *Self, s: []const u8, name: []const u8) !void {
    const ret = c.luaL_loadbufferx(self.L, s.ptr, s.len, name.ptr, null);
    if (ret != c.LUA_OK) {
        self.logger.err("{s}", .{c.lua_tolstring(self.L, -1, 0)});
        return error.LuaLoadingError;
    }
}
fn protectedCall(self: *Self) !void {
    const ret = c.lua_pcallk(self.L, 0, c.LUA_MULTRET, 0, 0, null);
    if (ret != c.LUA_OK) {
        self.logger.err("{s}", .{c.lua_tolstring(self.L, -1, 0)});
        return error.LuaCallError;
    }
}

pub fn pushUserData(lua: ?*c.lua_State, comptime field: std.meta.Tag(UserData), v: @FieldType(UserData, @tagName(field))) void {
    const ptr: *anyopaque = c.lua_newuserdatauv(lua, @sizeOf(UserData), 0).?;
    const data: *UserData = @ptrCast(@alignCast(ptr));
    data.* = @unionInit(UserData, @tagName(field), v);
    c.luaL_setmetatable(lua, "userdata");
}
fn checkAnyUserData(lua: ?*c.lua_State, index: c_int) *UserData {
    if (c.lua_isuserdata(lua, index) == 0) {
        _ = c.luaL_argerror(lua, index, "'userdata' expected");
    }
    const data = c.lua_touserdata(lua, index);
    return @ptrCast(@alignCast(data));
}
pub fn checkUserData(lua: ?*c.lua_State, comptime Tag: anytype, index: c_int) *UserData {
    const userdata = checkAnyUserData(lua, index);
    if (std.meta.activeTag(userdata.*) != Tag) {
        _ = c.luaL_argerror(lua, index, "invalid userdata type");
    }
    return userdata;
}
fn metaIndex(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkAnyUserData(lua, 1);
    const key = c.luaL_checklstring(lua, 2, null);
    const field = std.meta.stringToEnum(UserData.Field, std.mem.span(key)) orelse {
        _ = c.luaL_argerror(lua, 2, "unknown userdata field");
        return 0;
    };
    switch (userdata.*) {
        .vec2 => |*v| {
            switch (field) {
                .x => {
                    c.lua_pushnumber(lua, v.data[0]);
                    return 1;
                },
                .y => {
                    c.lua_pushnumber(lua, v.data[1]);
                    return 1;
                },
                else => {},
            }
        },
        .vec3 => |*v| {
            switch (field) {
                .x => {
                    c.lua_pushnumber(lua, v.data[0]);
                    return 1;
                },
                .y => {
                    c.lua_pushnumber(lua, v.data[1]);
                    return 1;
                },
                .z => {
                    c.lua_pushnumber(lua, v.data[2]);
                    return 1;
                },
                else => {},
            }
        },
        .vec4 => |*v| {
            switch (field) {
                .x => {
                    c.lua_pushnumber(lua, v.data[0]);
                    return 1;
                },
                .y => {
                    c.lua_pushnumber(lua, v.data[1]);
                    return 1;
                },
                .z => {
                    c.lua_pushnumber(lua, v.data[2]);
                    return 1;
                },
                .w => {
                    c.lua_pushnumber(lua, v.data[3]);
                    return 1;
                },
                else => {},
            }
        },
        .quat => |*v| {
            switch (field) {
                .x => {
                    c.lua_pushnumber(lua, v.x);
                    return 1;
                },
                .y => {
                    c.lua_pushnumber(lua, v.y);
                    return 1;
                },
                .z => {
                    c.lua_pushnumber(lua, v.z);
                    return 1;
                },
                .w => {
                    c.lua_pushnumber(lua, v.w);
                    return 1;
                },
                else => {},
            }
        },
    }
    return 0;
}
fn metaNewIndex(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkAnyUserData(lua, 1);
    const key = c.luaL_checklstring(lua, 2, null);
    const field = std.meta.stringToEnum(UserData.Field, std.mem.span(key)) orelse {
        _ = c.luaL_argerror(lua, 2, "unknown userdata field");
        return 0;
    };
    switch (userdata.*) {
        .vec2 => |*v| {
            switch (field) {
                .x => v.data[0] = @floatCast(c.luaL_checknumber(lua, 3)),
                .y => v.data[1] = @floatCast(c.luaL_checknumber(lua, 3)),
                else => {},
            }
        },
        .vec3 => |*v| {
            switch (field) {
                .x => v.data[0] = @floatCast(c.luaL_checknumber(lua, 3)),
                .y => v.data[1] = @floatCast(c.luaL_checknumber(lua, 3)),
                .z => v.data[2] = @floatCast(c.luaL_checknumber(lua, 3)),
                else => {},
            }
        },
        .vec4 => |*v| {
            switch (field) {
                .x => v.data[0] = @floatCast(c.luaL_checknumber(lua, 3)),
                .y => v.data[1] = @floatCast(c.luaL_checknumber(lua, 3)),
                .z => v.data[2] = @floatCast(c.luaL_checknumber(lua, 3)),
                .w => v.data[3] = @floatCast(c.luaL_checknumber(lua, 3)),
                else => {},
            }
        },
        .quat => |*v| {
            switch (field) {
                .x => v.x = @floatCast(c.luaL_checknumber(lua, 3)),
                .y => v.y = @floatCast(c.luaL_checknumber(lua, 3)),
                .z => v.z = @floatCast(c.luaL_checknumber(lua, 3)),
                .w => v.w = @floatCast(c.luaL_checknumber(lua, 3)),
                else => {},
            }
        },
    }
    return 0;
}
fn metaToString(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkAnyUserData(lua, 1);
    switch (userdata.*) {
        .vec2 => |*v| _ = c.lua_pushfstring(lua, "vec2(%f, %f)", v.data[0], v.data[1]),
        .vec3 => |*v| _ = c.lua_pushfstring(lua, "vec3(%f, %f, %f)", v.data[0], v.data[1], v.data[2]),
        .vec4 => |*v| _ = c.lua_pushfstring(lua, "vec4(%f, %f, %f, %f)", v.data[0], v.data[1], v.data[2], v.data[3]),
        .quat => |*v| _ = c.lua_pushfstring(lua, "quat(%f, %f, %f, %f)", v.x, v.y, v.z, v.w),
    }
    return 1;
}
fn metaAddVec(lua: ?*c.lua_State, ud: *UserData, comptime tag: std.meta.Tag(UserData)) c_int {
    const v = @field(ud, @tagName(tag));
    if (c.lua_isnumber(lua, 2) != 0) {
        const s: f32 = @floatCast(c.luaL_checknumber(lua, 2));
        pushUserData(lua, tag, v.add(.scalar(s)));
    } else {
        const b = checkUserData(lua, tag, 2);
        pushUserData(lua, tag, v.add(@field(b, @tagName(tag))));
    }
    return 1;
}
fn metaSubVec(lua: ?*c.lua_State, ud: *UserData, comptime tag: std.meta.Tag(UserData)) c_int {
    const v = @field(ud, @tagName(tag));
    if (c.lua_isnumber(lua, 2) != 0) {
        const s: f32 = @floatCast(c.luaL_checknumber(lua, 2));
        pushUserData(lua, tag, v.sub(.scalar(s)));
    } else {
        const b = checkUserData(lua, tag, 2);
        pushUserData(lua, tag, v.sub(@field(b, @tagName(tag))));
    }
    return 1;
}
fn metaMulVec(lua: ?*c.lua_State, ud: *UserData, comptime tag: std.meta.Tag(UserData)) c_int {
    const v = @field(ud, @tagName(tag));
    if (c.lua_isnumber(lua, 2) != 0) {
        const s: f32 = @floatCast(c.luaL_checknumber(lua, 2));
        pushUserData(lua, tag, v.mul(.scalar(s)));
    } else {
        const b = checkUserData(lua, tag, 2);
        pushUserData(lua, tag, v.mul(@field(b, @tagName(tag))));
    }
    return 1;
}
fn metaDivVec(lua: ?*c.lua_State, ud: *UserData, comptime tag: std.meta.Tag(UserData)) c_int {
    const v = @field(ud, @tagName(tag));
    if (c.lua_isnumber(lua, 2) != 0) {
        const s: f32 = @floatCast(c.luaL_checknumber(lua, 2));
        pushUserData(lua, tag, v.div(.scalar(s)));
    } else {
        const b = checkUserData(lua, tag, 2);
        pushUserData(lua, tag, v.div(@field(b, @tagName(tag))));
    }
    return 1;
}
fn metaAdd(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkAnyUserData(lua, 1);
    switch (userdata.*) {
        .vec2 => return metaAddVec(lua, userdata, .vec2),
        .vec3 => return metaAddVec(lua, userdata, .vec3),
        .vec4 => return metaAddVec(lua, userdata, .vec4),
        else => return c.luaL_error(lua, "invalid add operator on userdata"),
    }
    return 0;
}
fn metaSub(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkAnyUserData(lua, 1);
    switch (userdata.*) {
        .vec2 => return metaSubVec(lua, userdata, .vec2),
        .vec3 => return metaSubVec(lua, userdata, .vec3),
        .vec4 => return metaSubVec(lua, userdata, .vec4),
        else => return c.luaL_error(lua, "invalid sub operator on userdata"),
    }
    return 0;
}
fn metaMul(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkAnyUserData(lua, 1);
    switch (userdata.*) {
        .vec2 => return metaMulVec(lua, userdata, .vec2),
        .vec3 => return metaMulVec(lua, userdata, .vec3),
        .vec4 => return metaMulVec(lua, userdata, .vec4),
        else => return c.luaL_error(lua, "invalid mul operator on userdata"),
    }
    return 0;
}
fn metaDiv(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkAnyUserData(lua, 1);
    switch (userdata.*) {
        .vec2 => return metaDivVec(lua, userdata, .vec2),
        .vec3 => return metaDivVec(lua, userdata, .vec3),
        .vec4 => return metaDivVec(lua, userdata, .vec4),
        else => return c.luaL_error(lua, "invalid div operator on userdata"),
    }
    return 0;
}
fn metaNeg(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkAnyUserData(lua, 1);
    switch (userdata.*) {
        .vec2 => |*v| {
            pushUserData(lua, .vec2, v.neg());
            return 1;
        },
        .vec3 => |*v| {
            pushUserData(lua, .vec3, v.neg());
            return 1;
        },
        .vec4 => |*v| {
            pushUserData(lua, .vec4, v.neg());
            return 1;
        },
        else => return c.luaL_error(lua, "invalid neg operator on userdata"),
    }
    return 0;
}
fn mathVec(lua: ?*c.lua_State, comptime T: type) T {
    var v: T = undefined;
    if (c.lua_gettop(lua) == 0) {
        v = .zero();
    } else if (c.lua_gettop(lua) == 1) {
        v = .scalar(@floatCast(c.luaL_checknumber(lua, 1)));
    } else {
        inline for (0..T.N) |i| {
            v.data[i] = @floatCast(c.luaL_checknumber(lua, 1 + i));
        }
    }
    return v;
}
fn mathVec2(lua: ?*c.lua_State) callconv(.c) c_int {
    pushUserData(lua, .vec2, mathVec(lua, nux.Vec2));
    return 1;
}
fn mathVec3(lua: ?*c.lua_State) callconv(.c) c_int {
    pushUserData(lua, .vec3, mathVec(lua, nux.Vec3));
    return 1;
}
fn mathVec4(lua: ?*c.lua_State) callconv(.c) c_int {
    pushUserData(lua, .vec4, mathVec(lua, nux.Vec4));
    return 1;
}
fn mathQuat(lua: ?*c.lua_State) callconv(.c) c_int {
    pushUserData(lua, .quat, mathVec(lua, nux.Quat));
    return 1;
}
fn openMath(lua: *c.lua_State) !void {
    _ = c.luaL_newmetatable(lua, "userdata");
    const regs: [*]const c.luaL_Reg = &.{
        .{ .name = "__index", .func = metaIndex },
        .{ .name = "__newindex", .func = metaNewIndex },
        .{ .name = "__tostring", .func = metaToString },
        .{ .name = "__add", .func = metaAdd },
        .{ .name = "__sub", .func = metaSub },
        .{ .name = "__mul", .func = metaMul },
        .{ .name = "__div", .func = metaDiv },
        .{ .name = "__unm", .func = metaNeg },
        .{ .name = null, .func = null },
    };
    c.luaL_setfuncs(lua, regs, 0);
    c.lua_pop(lua, 1);

    c.lua_newtable(lua);
    const math_lib: [*]const c.luaL_Reg = &.{
        .{ .name = "vec2", .func = mathVec2 },
        .{ .name = "vec3", .func = mathVec3 },
        .{ .name = "vec4", .func = mathVec4 },
        .{ .name = null, .func = null },
    };
    c.luaL_setfuncs(lua, math_lib, 0);
    c.lua_setglobal(lua, "Math");
}
fn context(lua: ?*c.lua_State) *@This() {
    var ud: ?*anyopaque = undefined;
    _ = c.lua_getallocf(lua, &ud);
    return @as(*Self, @ptrCast(@alignCast(ud)));
}
fn require(lua: ?*c.lua_State) callconv(.c) c_int {
    _ = lua;
    // const self = context(lua);
    // const path = std.mem.span(c.luaL_checklstring(lua, 1, null));
    // if (self.node.findChild(self.package, path)) |_| {
    //     self.logger.info("FOUND {s}", .{path});
    // } else |_| {
    //     var buf: [256]u8 = undefined;
    //     var w = std.Io.Writer.fixed(&buf);
    //     w.print("{s}.lua", .{path}) catch {
    //         return c.luaL_error(lua, "invalid lua file path");
    //     };
    //     const final_path = buf[0..w.end];
    //     const id = self.script.load(self.package, final_path) catch {
    //         return c.luaL_error(lua, "failed to load lua file");
    //     };
    //     self.node.setName(id, path) catch unreachable;
    // }
    return 0;
}
fn openRequire(lua: *c.lua_State) !void {
    c.lua_pushcfunction(lua, require);
    c.lua_setglobal(lua, "require");
}

fn alloc(ud: ?*anyopaque, ptr: ?*anyopaque, osize: usize, nsize: usize) callconv(.c) ?*anyopaque {
    const alignment = @alignOf(UserData);
    const self: *Self = @ptrCast(@alignCast(ud.?));
    const allocator = self.allocator;
    if (@as(?[*]align(alignment) u8, @ptrCast(@alignCast(ptr)))) |prev_ptr| {
        const prev_slice = prev_ptr[0..osize];
        if (nsize == 0) {
            allocator.free(prev_slice);
            return null;
        }
        const new_ptr = allocator.realloc(prev_slice, nsize) catch return null;
        return new_ptr.ptr;
    } else if (nsize == 0) {
        return null;
    } else {
        const new_ptr = allocator.alignedAlloc(u8, .fromByteUnits(alignment), nsize) catch return null;
        return new_ptr.ptr;
    }
}

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;

    // Create lua VM
    self.L = c.lua_newstate(alloc, self, 0) orelse return error.Newstate;
    errdefer c.lua_close(self.L);

    // Open api
    c.luaL_openlibs(self.L);
    try openMath(self.L);
    try openRequire(self.L);
    self.bindings.openModules(self.L, core);
}
pub fn deinit(self: *Self) void {
    c.lua_close(self.L);
}
pub fn doString(self: *Self, source: []const u8, name: []const u8) !void {
    try loadString(self, source, name);
    try protectedCall(self);
}
pub fn callEntryPoint(self: *Self, entryPoint: []const u8) !void {
    const init_script = try self.file.read(entryPoint, self.allocator);
    defer self.allocator.free(init_script);
    try self.doString(init_script, entryPoint);
}
pub fn loadModule(self: *Self, module: *LuaModule, id: nux.ID, name: []const u8, source: []const u8) !void {
    const module_table = "M";
    const module_id = "id";

    // 1. Keep previous module on stack
    _ = c.lua_getglobal(self.L, module_table);

    // 2. Set global MODULE
    if (module.ref != 0) {
        _ = c.lua_rawgeti(self.L, c.LUA_REGISTRYINDEX, module.ref);
        c.luaL_unref(self.L, c.LUA_REGISTRYINDEX, module.ref);
    } else {
        c.lua_newtable(self.L);
        _ = c.lua_pushinteger(self.L, id.value());
        c.lua_setfield(self.L, -2, module_id);
    }
    std.debug.assert(c.lua_istable(self.L, -1));
    c.lua_setglobal(self.L, module_table);

    // 3. Execute module
    const prev = c.lua_gettop(self.L);
    try self.doString(source, name);

    // 4. Assign module table to registry
    const nret = c.lua_gettop(self.L) - prev;
    if (nret != 0) {
        if (nret != 1 or !c.lua_istable(self.L, -1)) {
            // "lua module '%s' returned value is not a table",
            return error.InvalidReturnedLuaScript;
        }
    } else {
        _ = c.lua_getglobal(self.L, module_table);
        if (!c.lua_istable(self.L, -1)) {
            // "lua module table '%s' removed"
            return error.LuaTableRemoved;
        }
    }
    module.ref = c.luaL_ref(self.L, c.LUA_REGISTRYINDEX);

    // 5. Reset previous MODULE global
    c.lua_setglobal(self.L, module_table);
}
pub fn unloadModule(self: *Self, module: *LuaModule) !void {
    // Unregister lua module
    if (module.ref != 0) {
        c.luaL_unref(self.L, c.LUA_REGISTRYINDEX, module.ref);
    }
}
fn callFunction(self: *Self, nargs: c_int, nreturns: c_int) !void {
    if (c.lua_pcallk(self.L, nargs, nreturns, 0, 0, null) != c.LUA_OK) {
        return error.LuaCallError;
    }
}
pub fn callModule(self: *Self, module: *LuaModule, name: [*c]const u8, nargs: c_int) !void {
    _ = c.lua_rawgeti(self.L, c.LUA_REGISTRYINDEX, module.ref);
    std.debug.assert(c.lua_istable(self.L, -1));
    // -1=M
    _ = c.lua_getfield(self.L, -1, name);
    // -2=M -1=F
    if (c.lua_isfunction(self.L, -1)) {
        c.lua_insert(self.L, -2 - nargs); // Move function before args
        c.lua_insert(self.L, -1 - nargs); // Move module before args
        try self.callFunction(1 + nargs, 0);
    } else {
        c.lua_pop(self.L, 2 + nargs); // Remove M + F + args
    }
}
