const nux = @import("../core.zig");
const zlua = @import("zlua");

pub const Module = struct {
    lua: *zlua.Lua,
    transform: *nux.transform.Module,

    pub fn init(self: *Module, core: *nux.Core) !void {
        self.transform = try core.findModule(nux.transform.Module);
        self.lua = try zlua.Lua.init(core.allocator);
    }

    pub fn deinit(self: *Module) void {
        self.lua.deinit();
    }
};
