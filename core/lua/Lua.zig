const nux = @import("../core.zig");
const ziglua = @import("zlua");
// const bindings = @import("bindings");

const Self = @This();
const hello_file = @embedFile("hello.lua");

lua: *ziglua.Lua,
transform: *nux.Transform,
logger: *nux.Logger,

const Context = struct {};

fn adder(lua: *ziglua.Lua) i32 {
    const a = lua.toInteger(1) catch 0;
    const b = lua.toInteger(2) catch 0;
    lua.pushInteger(a + b);
    return 1;
}

pub fn init(self: *Self, core: *nux.Core) !void {
    self.lua = try ziglua.Lua.init(core.allocator);
    self.lua.openBase();

    // self.lua.ref

    self.lua.newTable();
    self.lua.setFuncs(&.{.{ .name = "add", .func = ziglua.wrap(adder) }}, 0);
    self.lua.setGlobal("transform");

    try self.lua.doString(hello_file);

    self.logger.info("{}", .{try self.lua.toInteger(-1)});
}

pub fn deinit(self: *Self) void {
    self.lua.deinit();
}
