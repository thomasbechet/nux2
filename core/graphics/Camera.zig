const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

components: nux.Components(struct {}),
node: *nux.Node,
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
