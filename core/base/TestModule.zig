const nux = @import("../core.zig");
const Logger = @import("logger.zig");
const Self = @This();

const MyObject = struct {
    value: u32,
};

logger: *Logger,
objects: *nux.Objects(MyObject),

pub fn init(self: *Self, core: *nux.Core) !void {}
pub fn deinit(self: *Self) void {}

pub fn new(self: *Self, parent: nux.ObjectID) !nux.ObjectID {
    return (try self.objects.new(parent)).id;
}
