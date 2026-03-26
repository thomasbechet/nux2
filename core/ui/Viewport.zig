const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

/// Viewport is a render target :
/// What to render ? (camera ? gui ?)
/// Where to render ? (screen ? texture ?)
///
/// How is describe by the components of what.
const Source = union(enum) {
    camera: nux.ID,
    ui: nux.ID,
    texture: nux.ID,
};

const Component = struct {
    source: Source = undefined,
    target: ?nux.ID = null,
    commands: nux.Graphics.CommandBuffer,

    pub fn init(mod: *Self) !Component {
        return .{
            .commands = .init(mod.allocator),
        };
    }
    pub fn deinit(self: *Component, _: *Self) void {
        self.commands.deinit();
    }
};

allocator: nux.Platform.Allocator,
node: *nux.Node,
texture: *nux.Texture,
gpu: *nux.GPU,
components: nux.Components(Component),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn onRender(self: *Self) !void {
    var it = self.components.iterator();
    while (it.next()) |entry| {
        try self.gpu.render(&entry.component.commands);
        entry.component.commands.reset();
    }

    // 1. Render to texture
    // 2. Render to screen
}

pub fn setUI(self: *Self, id: nux.ID, widget: nux.ID) !void {
    const viewport = try self.components.get(id);
    viewport.source = .{ .ui = widget };
}
