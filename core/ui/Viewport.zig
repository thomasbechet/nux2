const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

/// Viewport is a render target :
/// What to render ? (camera ? gui ?)
/// Where to render ? (screen ? texture ?)
///
/// How is describe by the components of what.
pub const Component = struct {
    camera: ?nux.ID = null,
    widget: ?nux.ID = null,
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
widget: *nux.Widget,
components: nux.Components(Component),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
pub fn onUpdate(self: *Self) !void {

    // Update GUI layout
    var it = self.components.iterator();
    while (it.next()) |entry| {
        if (entry.component.widget) |widget| {
            try self.widget.layoutWidget(widget, entry.component);            
            try self.widget.renderWidget(widget, entry.component);            
        }
    }
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

pub fn setWidget(self: *Self, id: nux.ID, widget: nux.ID) !void {
    const viewport = try self.components.get(id);
    viewport.widget = widget;
}
pub fn setCamera(self: *Self, id: nux.ID, camera: nux.ID) !void {
    const viewport = try self.components.get(id);
    viewport.camera = camera;
}
