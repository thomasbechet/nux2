const std = @import("std");
const nux = @import("../nux.zig");
const zigimg = @import("zigimg");

const Module = @This();
const Node = struct {
    data: ?[]u8 = null,
    size: nux.Vec2 = .zero(),
    path: ?[]const u8 = null,
    pub fn init(_: *Module) !@This() {
        return .{};
    }
    pub fn deinit(self: *@This(), mod: *Module) void {
        if (self.data) |data| {
            mod.allocator.free(data);
        }
        if (self.path) |path| {
            mod.allocator.free(path);
        }
    }
    pub fn save(self: *@This(), mod: *Module, writer: *nux.Writer) !void {
        _ = mod;
        try writer.write(self.path);
    }
    pub fn load(self: *@This(), mod: *Module, reader: *nux.Reader) !void {
        if (try reader.takeOptionalBytes()) |path| {
            self.path = try mod.allocator.dupe(u8, path);
            try self.loadEntry(mod, path);
        }
    }
    fn loadEntry(self: *@This(), mod: *Module, path: []const u8) !void {
        const data = try mod.disk.readEntry(path, mod.allocator);
        errdefer mod.allocator.free(data);
        var image = try zigimg.Image.fromMemory(mod.allocator, data);
        defer image.deinit(mod.allocator);
        self.data = data;
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
pub fn load(self: *Module, parent: nux.NodeID, path: []const u8) !nux.NodeID {
    const node = try self.nodes.new(parent);
    try node.data.loadEntry(self, path);
    return node.id;
}
