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
    const Field = enum { x, y, z, w, normal, position };
    vec2: nux.Vec2,
    vec3: nux.Vec3,
    vec4: nux.Vec4,
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

// pub fn set(objs: *@This(), id: ObjectID, comptime field_name: std.meta.FieldEnum(T), value: std.meta.FieldType(T, field_name)) void {
fn pushUserData(lua: ?*c.lua_State, comptime field: std.meta.Tag(UserData), v: std.meta.TagPayload(UserData, field)) void {
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
fn checkUserData(lua: ?*c.lua_State, comptime Tag: anytype, index: c_int) *UserData {
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
    }
    return 0;
}
fn metaToString(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkAnyUserData(lua, 1);
    switch (userdata.*) {
        .vec2 => |*v| _ = c.lua_pushfstring(lua, "vec2(%f, %f)", v.data[0], v.data[1]),
        .vec3 => |*v| _ = c.lua_pushfstring(lua, "vec3(%f, %f, %f)", v.data[0], v.data[1], v.data[2]),
        .vec4 => |*v| _ = c.lua_pushfstring(lua, "vec3(%f, %f, %f, %f)", v.data[0], v.data[1], v.data[2], v.data[3]),
    }
    return 1;
}
fn metaAddVec(lua: ?*c.lua_State, comptime T: type, v: T) c_int {
    if (c.lua_gettop(lua) == 1) {
        const s: f32 = @floatCast(c.luaL_checknumber(lua, 2));
        pushUserData(lua, .vec2, v.add(.scalar(s)));
    } else {
        const b = checkUserData(lua, .vec2, 2);
        pushUserData(lua, .vec2, v.add(b.vec2));
    }
    return 1;
}
fn metaAdd(lua: ?*c.lua_State) callconv(.c) c_int {
    const userdata = checkAnyUserData(lua, 1);
    switch (userdata.*) {
        .vec2 => |*v| {
            if (c.lua_gettop(lua) == 1) {
                const s: f32 = @floatCast(c.luaL_checknumber(lua, 2));
                pushUserData(lua, .vec2, v.add(.scalar(s)));
            } else {
                const b = checkUserData(lua, .vec2, 2);
                pushUserData(lua, .vec2, v.add(b.vec2));
            }
            return 1;
        },
        .vec3 => |*v| {
            const b = checkUserData(lua, .vec3, 2);
            pushUserData(lua, .vec3, v.add(b.vec3));
            return 1;
        },
        .vec4 => |*v| {
            const b = checkUserData(lua, .vec4, 2);
            pushUserData(lua, .vec4, v.add(b.vec4));
            return 1;
        },
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
    }
    return 0;
}
fn vmathVec(lua: ?*c.lua_State, comptime T: type) T {
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
fn vmathVec2(lua: ?*c.lua_State) callconv(.c) c_int {
    pushUserData(lua, .vec2, vmathVec(lua, nux.Vec2));
    return 1;
}
fn vmathVec3(lua: ?*c.lua_State) callconv(.c) c_int {
    pushUserData(lua, .vec3, vmathVec(lua, nux.Vec3));
    return 1;
}
fn vmathVec4(lua: ?*c.lua_State) callconv(.c) c_int {
    pushUserData(lua, .vec4, vmathVec(lua, nux.Vec4));
    return 1;
}
fn openVMath(lua: *c.lua_State) !void {
    _ = c.luaL_newmetatable(lua, "userdata");
    const regs: [*]const c.luaL_Reg = &.{
        .{ .name = "__index", .func = metaIndex },
        .{ .name = "__newindex", .func = metaNewIndex },
        .{ .name = "__tostring", .func = metaToString },
        .{ .name = "__add", .func = metaAdd },
        .{ .name = "__unm", .func = metaNeg },
        .{ .name = null, .func = null },
    };
    c.luaL_setfuncs(lua, regs, 0);
    c.lua_pop(lua, 1);

    c.lua_newtable(lua);
    const vmath_lib: [*]const c.luaL_Reg = &.{
        .{ .name = "vec2", .func = vmathVec2 },
        .{ .name = "vec3", .func = vmathVec3 },
        .{ .name = "vec4", .func = vmathVec4 },
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
