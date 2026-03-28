const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const Component = struct {

};

components: nux.Components(Component),
node: *nux.Node,
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
