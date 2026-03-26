const nux = @import("../nux.zig");

const Self = @This();

/// Viewport is a render target 
/// What to render ? (camera ? gui ?)
/// Where to render ? (screen ? texture ?)
///
/// Render step
/// 1. Update UI layouts using viewports with UI
/// 2. Render viewports to texture
/// 3. Render viewports to screen

const Source = union(enum) {
    camera: nux.ID,
    ui: nux.ID,
    texture: nux.ID,
};

const Component = struct {
    source: Source = undefined,
    target: ?nux.ID = null,
};

texture: *nux.Texture,
camera: *nux.Camera,
ui_element: *nux.UIElement,
components: nux.Components(Component),

pub fn onUpdate(self: *Self) !void {
    var it = self.components.iterator();
    while (it.next()) |entry| {

        

        if (entry.component.target) |id| {
            // render to texture
        } else {
            // render to main framebuffer
        }

        switch (entry.component.source) {
            .camera => |id| {

            },
            .texture => |id| {

            }
        }
    }
}
