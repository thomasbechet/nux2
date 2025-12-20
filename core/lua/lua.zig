const nux = @import("../core.zig");
const zlua = @import("zlua");

pub const Module = struct {
    vm: *zlua.Lua,
    transform: *@import("../base/transform.zig"),

    pub fn init(self: *Module, core: *nux.Core) !void {
        self.transform = try core.getModule();
        self.lua = try zlua.Lua.init(core.allocator);
        defer self.lua.deinit();
    }

    pub fn deinit(_: *Module) void {}
};
