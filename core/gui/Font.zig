const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Font = struct {

    const Glyph = struct {
        box: nux.Box2,
    };

    handle: ?nux.GPU.Texture = null,
    width: usize = 0,
    height: usize = 0,
    glyphs: std.ArrayList(?Glyph),
    font: nux.ID = .null,
};

allocator: std.mem.Allocator,
gpu: *nux.GPU,
components: nux.Components(Font),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
