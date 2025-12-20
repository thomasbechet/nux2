const nux = @import("../core.zig");
const zlua = @import("zlua");

const Module = @This();

vm: *zlua.Lua,
transform: *@import("../base/transform.zig"),

pub fn init(self: *Module, core: *nux.Core) !void {
    self.transform = try core.getModule();
    self.lua = try zlua.Lua.init(core.allocator);
    defer self.lua.deinit();
}
