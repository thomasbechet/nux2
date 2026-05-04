const std = @import("std");
const nux = @import("../nux.zig");
const monogram = @import("monogram.zig");

const default_font_id = "fonts/default";

const Self = @This();

pub const Component = struct {
    const Glyph = struct {
        box: nux.Box2i,
        advance: i32,
    };

    pub const GlyphIterator = struct {
        const Item = struct {
            glyph: ?Glyph = null, // null if no associated glyph (such as newline)
            codepoint: u32,
        };
        font: *Component,
        iterator: std.unicode.Utf8Iterator,

        pub fn next(self: *GlyphIterator) ?Item {
            while (self.iterator.nextCodepoint()) |codepoint| {
                if (self.font.getGlyph(codepoint)) |glyph| {
                    return .{ .glyph = glyph, .codepoint = codepoint };
                } else {
                    return .{ .glyph = null, .codepoint = codepoint };
                }
            }
            return null;
        }
    };

    glyphs: []?Glyph = undefined,
    texture: nux.ID = .null,

    pub fn deinit(self: *Component, mod: *Self) void {
        mod.allocator.free(self.glyphs);
    }

    pub fn iterate(self: *Component, text: []const u8) GlyphIterator {
        return .{
            .font = self,
            .iterator = std.unicode.Utf8View.initUnchecked(text).iterator(),
        };
    }

    pub fn getGlyph(self: *Component, codepoint: u32) ?Glyph {
        const index: usize = @intCast(codepoint);
        if (index >= self.glyphs.len) {
            return null;
        }
        return self.glyphs[index];
    }
};

allocator: std.mem.Allocator,
components: nux.Components(Component),
node: *nux.Node,
texture: *nux.Texture,

fn createDefaultFont(self: *Self) !void {
    const id = try self.node.createPath(self.node.getRoot(), default_font_id);

    // Find min/max
    var max: usize = 0;
    for (monogram.glyphs) |glyph| {
        max = @max(@as(usize, @intCast(glyph.char)), max);
    }

    // Create font
    const font = try self.components.addPtr(id);
    font.texture = id;
    font.glyphs = try self.allocator.alloc(?Component.Glyph, max + 1);
    errdefer self.allocator.free(font.glyphs);
    for (0..font.glyphs.len) |i| {
        font.glyphs[i] = null;
    }

    // Generate sprite font
    const width =
        monogram.glyphs.len * monogram.width;
    const height = monogram.height;
    try self.texture.addTransparent(id, width, height);
    const texture = try self.texture.components.get(id);

    // Find min/max char index
    var box: nux.Box2i = .init(0, 0, monogram.width, monogram.height);
    for (monogram.glyphs) |glyph| {

        // Render glyph
        nux.Rasterizer.renderBitmap(
            .{ .pixels = texture.data.?, .width = width, .height = height },
            glyph.bitmap,
            box,
        );

        // Setup glyph
        font.glyphs[@intCast(glyph.char)] = .{
            .box = box,
            .advance = box.w() + 1,
        };

        // Move to next glyph box
        box.translate(.init(monogram.width, 0));
    }
}
pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    try self.createDefaultFont();
}
pub fn default(self: *Self) !nux.ID {
    return self.node.findGlobal(default_font_id);
}
pub fn measure(self: *Self, id: nux.ID, text: []const u8) !nux.Vec2i {
    const font = try self.components.get(id);
    var size: nux.Vec2i = .zero();
    var it = font.iterate(text);
    var line_height: i32 = 0;
    var line_width: i32 = 0;
    while (it.next()) |item| {
        if (item.glyph) |glyph| {
            line_width += glyph.advance;
            line_height = @max(line_height, glyph.box.h());
        } else if (item.codepoint == '\n') {
            size.data[0] = @max(size.data[0], line_width);
            size.data[1] += line_height;
            line_height = 0;
            line_width = 0;
        }
    }
    size.data[0] = @max(size.data[0], line_width);
    size.data[1] += line_height;
    return size;
}
