const nux = @import("../core.zig");
const ziglua = @import("ziglua");
const bindings = @import("bindings");

const Self = @This();
const hello_file = @embedFile("hello.lua");

lua: *ziglua.Lua,
transform: *nux.Transform,
logger: *nux.Logger,

const Context = struct {};

pub fn init(self: *Self, core: *nux.Core) !void {
    self.lua = try ziglua.Lua.init(core.allocator);
    self.lua.openBase();

    bindings.openModules(self.lua);

    // self.lua.protectedCall(.{}) catch {
    //     self.logger.info("ERROR: {s}", .{self.lua.toString(-1)});
    // };

    self.lua.doString(hello_file) catch {
        self.logger.info("ERROR: {s}", .{try self.lua.toString(-1)});
    };
    self.logger.info("{}", .{try self.lua.toInteger(-1)});
}

pub fn deinit(self: *Self) void {
    self.lua.deinit();
}
