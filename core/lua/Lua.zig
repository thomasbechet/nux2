const nux = @import("../core.zig");
const std = @import("std");
// const bindings = @import("bindings");

const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

const Self = @This();
const hello_file = @embedFile("hello.lua");

const UserData = union(enum) {
    const Field = enum { x, y, z, w };
    vec2: nux.Vec2,
};

const Error = error{
    NewState,
    LuaSyntax,
    OutOfMemory,
    LuaRuntime,
    LuaMsgHandler,
};

allocator: std.mem.Allocator,
transform: *nux.Transform,
logger: *nux.Logger,
lua: *c.lua_State,

fn loadString(lua: *c.lua_State, s: [:0]const u8) !void {
    const ret = c.luaL_loadstring(lua, s.ptr);
    switch (ret) {
        c.LUA_OK => {},
        c.LUA_ERRSYNTAX => return error.LuaSyntax,
        c.LUA_ERRMEM => return error.OutOfMemory,
        c.LUA_ERRRUN => return error.LuaRuntime,
        c.LUA_ERRERR => return error.LuaMsgHandler,
        else => unreachable,
    }
}
fn protectedCall(lua: *c.lua_State) !void {
    const ret = c.lua_pcallk(lua, 0, c.LUA_MULTRET, 0, 0, null);
    switch (ret) {
        c.LUA_OK => {},
        c.LUA_ERRRUN => return error.LuaRuntime,
        c.LUA_ERRMEM => return error.OutOfMemory,
        c.LUA_ERRERR => return error.LuaMsgHandler,
        else => unreachable,
    }
}
fn doString(lua: *c.lua_State, s: [:0]const u8) !void {
    try loadString(lua, s);
    try protectedCall(lua);
}

fn newUserData(lua: ?*c.lua_State) *UserData {
    const ptr: *anyopaque = c.lua_newuserdatauv(lua, @sizeOf(UserData), 0).?;
    const data: *UserData = @ptrCast(@alignCast(ptr));
    c.luaL_setmetatable(lua, "userdata");
    return data;
}
fn checkUserData(lua: ?*c.lua_State, index: c_int) *UserData {
    if (c.lua_isuserdata(lua, index) == 0) {
        _ = c.luaL_argerror(lua, index, "'userdata' expected");
    }
    const data = c.lua_touserdata(lua, index);
    return @ptrCast(@alignCast(data));
}
fn metaIndex(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkUserData(lua, 1);
    const key = c.luaL_checklstring(lua, 2, null);
    const field = std.meta.stringToEnum(UserData.Field, std.mem.span(key)) orelse {
        _ = c.luaL_argerror(lua, 2, "unknown userdata field");
        return 0;
    };
    switch (userdata.*) {
        .vec2 => {
            switch (field) {
                .x => {
                    c.lua_pushnumber(lua, userdata.vec2.data[0]);
                    return 1;
                },
                .y => {
                    c.lua_pushnumber(lua, userdata.vec2.data[1]);
                    return 1;
                },
                else => {},
            }
        },
    }
    return 0;
}
fn vmathVec2(lua: ?*c.lua_State) callconv(.c) c_int {
    var v = newUserData(lua);
    v.vec2.data[0] = 1;
    v.vec2.data[1] = 2;
    return 1;
}
fn openVMath(lua: *c.lua_State) !void {
    _ = c.luaL_newmetatable(lua, "userdata");
    const regs: [*]const c.luaL_Reg = &.{
        .{ .name = "__index", .func = metaIndex },
        .{ .name = null, .func = null },
    };
    c.luaL_setfuncs(lua, regs, 0);
    c.lua_pop(lua, 1);

    c.lua_newtable(lua);
    const vmath_lib: [*]const c.luaL_Reg = &.{
        .{ .name = "vec2", .func = vmathVec2 },
        .{ .name = null, .func = null },
    };
    c.luaL_setfuncs(lua, vmath_lib, 0);
    c.lua_setglobal(lua, "vmath");
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

pub fn init(self: *Self, core: *nux.Core) !void {
    self.allocator = core.allocator;
    self.lua = c.lua_newstate(alloc, self, 0) orelse return error.newstate;
    errdefer c.lua_close(self.lua);

    // open api
    c.luaL_openlibs(self.lua); // base api
    try openVMath(self.lua); // vmath

    doString(self.lua, hello_file) catch {
        self.logger.err("{s}", .{c.lua_tolstring(self.lua, -1, 0)});
    };
}
pub fn deinit(self: *Self) void {
    c.lua_close(self.lua);
}
