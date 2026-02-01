const std = @import("std");
const nux = @import("../nux.zig");

const Module = @This();
const Node = struct {
    data: ?[]u8 = null,
    path: ?[]const u8 = null,
    pub fn init(_: *Module) !@This() {
        return .{};
    }
    pub fn deinit(self: *@This(), mod: *Module) void {
        if (self.path) |path| {
            mod.allocator.free(path);
        }
    }
    pub fn save(self: *@This(), _: *Module, writer: *nux.Writer) !void {
        try writer.write(self.path);
    }
    pub fn load(self: *@This(), mod: *Module, reader: *nux.Reader) !void {
        if (try reader.takeOptionalBytes()) |path| {
            self.path = try mod.allocator.dupe(u8, path);
            try self.loadEntry(mod, path);
        }
    }
};

nodes: nux.NodePool(Node),
node: *nux.Node,
logger: *nux.Logger,
disk: *nux.Disk,
allocator: std.mem.Allocator,

pub fn init(self: *Module, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
