const std = @import("std");
const nux = @import("../nux.zig");

const monogram = @import("monogram.zig");
const default_font_id = "Fonts/Default";

const Self = @This();
const Font = struct {
    const Glyph = struct {
        box: nux.Box2,
    };

    glyphs: std.ArrayList(?Glyph) = .empty,
    texture: nux.ID = .null,

    pub fn deinit(self: *Font, mod: *Self) void {
        self.glyphs.deinit(mod.allocator);
    }

    fn getGlyph(self: *Font, c: u8) ?Glyph {
        const index: usize = @intCast(c);
        if (index >= self.glyphs.items.len) {
            return null;
        }
        return self.glyphs.items[index];
    }
};

allocator: std.mem.Allocator,
components: nux.Components(Font),
node: *nux.Node,
texture: *nux.Texture,
logger: *nux.Logger,

fn u60ToBytesBE(v: u60) [8]u8 {
    return [8]u8{
        @intCast((v >> 56) & 0xFF),
        @intCast((v >> 48) & 0xFF),
        @intCast((v >> 40) & 0xFF),
        @intCast((v >> 32) & 0xFF),
        @intCast((v >> 24) & 0xFF),
        @intCast((v >> 16) & 0xFF),
        @intCast((v >> 8) & 0xFF),
        @intCast((v) & 0xFF),
    };
}

fn u60ToBytesLE(value: u64) [8]u8 {
    const v = value & 0x0FFFFFFFFFFFFFFF;

    return [8]u8{
        @intCast(0xFF & (v)),
        @intCast(0xFF & (v >> 8)),
        @intCast(0xFF & (v >> 16)),
        @intCast(0xFF & (v >> 24)),
        @intCast(0xFF & (v >> 32)),
        @intCast(0xFF & (v >> 40)),
        @intCast(0xFF & (v >> 48)),
        @intCast(0xFF & (v >> 56)),
    };
}

fn createDefaultFont(self: *Self) !void {
    const id = try self.node.createPath(self.node.getRoot(), default_font_id);
    // Generate sprite font
    const width =
        monogram.glyphs.len * monogram.width;
    const height = monogram.height;
    try self.texture.addTransparent(id, width, height);
    const texture = try self.texture.components.get(id);

    // Find min/max char index
    var max: usize = 0;
    var box: nux.Box2i = .init(0, 0, monogram.width, monogram.height);
    for (monogram.glyphs) |glyph| {

        // Find min/max
        max = @max(@as(usize, @intCast(glyph.char)), max);

        // Render glyph
        const bitmap = u60ToBytesLE(glyph.bitmap);
        nux.Rasterizer.renderBitmap(
            .{ .pixels = texture.data.?, .width = width, .height = height },
            &bitmap,
            box,
        );
        box.translate(.init(monogram.width, 0));
    }
    const font = try self.components.addPtr(id);
    font.glyphs = try .initCapacity(self.allocator, max);
    font.texture = id;
}
pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    try self.createDefaultFont();
}
pub fn default(self: *Self) nux.ID {
    return self.node.findGlobal(default_font_id);
}
