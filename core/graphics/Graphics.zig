const std = @import("std");
const nux = @import("../nux.zig");
const Gltf = @import("zgltf").Gltf;

const Module = @This();

node: *nux.Node,
logger: *nux.Logger,
disk: *nux.Disk,
allocator: std.mem.Allocator,

pub fn init(self: *Module, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn loadGltf(self: *Module, path: []const u8) !nux.NodeID {
    const buffer = try std.fs.cwd().readFileAllocOptions(self.allocator, path, 2_000_000, null, std.mem.Alignment.@"4", null);
    defer self.allocator.free(buffer);

    var gltf = Gltf.init(self.allocator);
    defer gltf.deinit();

    try gltf.parse(buffer);

    for (gltf.data.nodes) |node| {
        const message =
            \\\ Node's name: {s}
            \\\ Children count: {}
            \\\ Have skin: {}
        ;

        self.logger.info(message, .{
            node.name orelse "Unnamed Node",
            node.children.len,
            node.skin != null,
        });
    }

    // Or use the debufPrint method.
    gltf.debugPrint();

    return .null;
}
