const nux = @import("../core.zig");
const zlua = @import("zlua");
const bindings = @import("bindings");

const Self = @This();
const hello_file = @embedFile("hello.lua");

lua: *zlua.Lua,
transform: *nux.Transform,
logger: *nux.Logger,

fn adder(lua: *zlua.Lua) i32 {
    const a = lua.toInteger(1) catch 0;
    const b = lua.toInteger(2) catch 0;
    lua.pushInteger(a + b);
    return 1;
}

pub fn init(self: *Self, core: *nux.Core) !void {
    self.lua = try zlua.Lua.init(core.allocator);
    self.lua.openBase();

    self.lua.pushFunction(zlua.wrap(adder));
    self.lua.setGlobal("add");

    try self.lua.doString(hello_file);

    self.logger.info("{}", .{try self.lua.toInteger(-1)});
    self.logger.info("{s}", .{bindings.string});
}

pub fn deinit(self: *Self) void {
    self.lua.deinit();
}
