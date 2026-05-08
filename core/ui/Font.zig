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
            position: nux.Vec2i,
            glyph: Glyph,
            advance_x: i32,
            advance_y: i32,
        };

        font: *Component,
        scale: i32,
        available: nux.Vec2i,
        iterator: std.unicode.Utf8Iterator,
        cursor: nux.Vec2i = .zero(),
        line_size: nux.Vec2i = .zero(),

        fn measureLineSize(self: *GlyphIterator) nux.Vec2i {
            var it = self.iterator;

            var line_width: i32 = 0;
            var line_height: i32 = 0;
            var word_width: i32 = 0;
            var space_width: i32 = 0;

            var in_word: bool = false;
            while (it.nextCodepoint()) |codepoint| {
                const glyph = self.font.getGlyph(codepoint) orelse continue;
                const advance = glyph.advance * self.scale;
                const height = glyph.box.h() * self.scale;

                // Add glyph size
                if (codepoint == ' ') {
                    if (in_word) { // Leaving word
                        space_width = 0;
                        word_width = 0;
                        in_word = false;
                    }
                    space_width += advance;
                } else {
                    if (!in_word) { // Entering word (keep space width)
                        word_width = 0;
                        in_word = true;
                    }
                    word_width += advance;
                }
                line_width += advance;

                // Detect line wrap
                if (line_width > self.available.x()) { // line wrap
                    // Remove last word and space
                    line_width -= advance;
                    line_width -= word_width; // if in word
                    line_width -= space_width; // if in space or remaining space or word
                    break;
                } else if (codepoint == '\n') { // new line
                    break;
                }

                line_height = @max(line_height, height);
            }

            return .init(line_width, line_height);
        }

        pub fn next(self: *GlyphIterator) ?Item {

            // Measure line
            if (self.line_size.x() == 0) {
                self.line_size = self.measureLineSize();
                // TODO: set offset based on aligment
            }

            // Check end of available height
            if (self.cursor.y() + self.line_size.y() > self.available.y()) {
                return null;
            }

            while (self.iterator.nextCodepoint()) |codepoint| {

                // Fetch glyph
                const glyph = self.font.getGlyph(codepoint) orelse continue;
                const advance = glyph.advance * self.scale;
                const height = glyph.box.h() * self.scale;

                // Check new line
                if (self.cursor.x() >= self.line_size.x()) {
                    self.cursor.data[0] = 0;

                    self.cursor.data[1] += self.line_size.y();
                    self.line_size = .zero();
                }

                const item = Item{
                    .glyph = glyph,
                    .position = self.cursor,
                    .advance_x = advance,
                    .advance_y = height,
                };

                // Update cursor position
                self.cursor.data[0] += advance;

                return item;
            }

            return null;
        }
    };

    glyphs: []?Glyph = undefined,
    texture: nux.ID = .null,

    pub fn deinit(self: *Component, mod: *Self) void {
        mod.allocator.free(self.glyphs);
    }

    pub fn render(self: *Component, text: []const u8, scale: i32, available: ?nux.Vec2i) GlyphIterator {
        return .{
            .font = self,
            .iterator = std.unicode.Utf8View.initUnchecked(text).iterator(),
            .scale = scale,
            .available = available orelse .maxValue(),
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
pub fn measure(self: *Self, id: nux.ID, text: []const u8, scale: i32, available: ?nux.Vec2i) !nux.Vec2i {
    const font = try self.components.get(id);
    var it = font.render(text, scale, available);
    var size: nux.Vec2i = .zero();
    while (it.next()) |item| {
        size.data[0] = @max(size.x(), item.position.x() + item.advance_x);
        size.data[1] = @max(size.y(), item.position.y() + item.advance_y);
    }
    return size;
}
