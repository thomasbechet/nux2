const nux = @import("../nux.zig");

const Self = @This();

platform: nux.Platform.System,

fn init(self: *Self, core: *const nux.Core) !void {
    self.platform = core.platform.system;
}


