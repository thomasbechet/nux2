const std = @import("std");
const nux = @import("../nux.zig");
const monogram = @import("monogram.zig");

const default_font_id = "fonts/default";

const Self = @This();

const LineIterator = struct {
    const Line = struct {
        iterator: std.unicode.Utf8Iterator,
        size: nux.Vec2i,
    };

    text: []const u8,
    font: *const Component,
    scale: i32,
    available: nux.Vec2i,
    start: usize = 0,

    fn init(text: []const u8, font: *const Component, scale: i32, available: nux.Vec2i) LineIterator {
        return .{
            .text = text,
            .font = font,
            .scale = scale,
            .available = available,
        };
    }

    fn next(self: *LineIterator) ?Line {
        if (self.start >= self.text.len) {
            return null;
        }

        var size: nux.Vec2i = .zero();
        var line_width: i32 = 0;
        var line_height: i32 = 0;
        var was_word: bool = false;
        var index: usize = self.start;
        var start = self.start;
        var break_pos: usize = 0;
        var it = std.unicode.Utf8View.initUnchecked(self.text[self.start..]).iterator();
        var trim: bool = true;
        var last_advance_x: i32 = 0;
        while (it.nextCodepoint()) |cp| : (index += 1) {
            const glyph = self.font.getGlyph(cp) orelse continue;
            const width = glyph.box.w() * self.scale;
            const height = glyph.box.h() * self.scale;
            const advance_x = glyph.advance * self.scale;

            // Trim leading spaces
            if (trim) {
                if (cp == ' ') {
                    start += 1;
                    continue;
                } else {
                    trim = false;
                }
            }

            // Detect end of word
            const is_word = cp != ' ';
            if (!is_word and was_word) {
                size.data[0] = line_width;
                size.data[1] = line_height;
                break_pos = index;
            }
            was_word = is_word;

            // Update line width / height
            line_width += width;
            line_height = @max(line_height, height);

            // Detect wrap
            if (line_width > self.available.x()) {
                break;
            }

            // Advance line
            last_advance_x = @max(0, advance_x - width);
            line_width += last_advance_x;
        }

        // Special case for end word
        if (index == self.text.len) {
            size.data[0] = line_width;
            size.data[1] = line_height;
            break_pos = index;
        }

        // No characters = no line
        if (start >= break_pos) {
            return null;
        }
        self.start = break_pos;

        // Remove remaining advance
        size.data[0] = @max(0, size.data[0] - last_advance_x);

        return .{
            .iterator = std.unicode.Utf8View.initUnchecked(self.text[start..break_pos]).iterator(),
            .size = size,
        };
    }
};

const GlyphIterator = struct {
    const Item = struct {
        position: nux.Vec2i,
        glyph: Glyph,
        advance_x: i32,
        advance_y: i32,
    };

    lines: LineIterator,
    line: ?LineIterator.Line,
    alignment: nux.Widget.Alignment,
    cursor: nux.Vec2i = .zero(),

    pub fn init(
        text: []const u8,
        font: *const Component,
        scale: i32,
        alignment: nux.Widget.Alignment,
        available: nux.Vec2i,
    ) GlyphIterator {
        return .{
            .lines = .init(text, font, scale, available),
            .line = null,
            .alignment = alignment,
        };
    }

    pub fn next(self: *GlyphIterator) ?Item {
        while (true) {

            // Fetch line
            if (self.line == null) {
                self.line = self.lines.next();
                if (self.line == null) {
                    return null;
                }
                switch (self.alignment) {
                    .start => self.cursor.data[0] = 0,
                    .center => self.cursor.data[0] = @divTrunc(self.lines.available.x() - self.line.?.size.x(), 2),
                    .end => self.cursor.data[0] = self.lines.available.x() - self.line.?.size.x(),
                }
            }
            const line = &self.line.?;

            // Check end of available height
            if (self.cursor.y() + line.size.y() > self.lines.available.y()) {
                return null;
            }

            if (line.iterator.nextCodepoint()) |codepoint| {

                // Fetch glyph
                const glyph = self.lines.font.getGlyph(codepoint) orelse continue;
                const advance = glyph.advance * self.lines.scale;
                const item = Item{
                    .glyph = glyph,
                    .position = self.cursor,
                    .advance_x = advance,
                    .advance_y = self.line.?.size.y(),
                };

                // Update cursor position
                self.cursor.data[0] += advance;

                return item;
            } else {
                self.cursor.data[1] += line.size.y();
                self.line = null;
            }
        }

        return null;
    }
};

const Glyph = struct {
    box: nux.Box2i,
    advance: i32,
};

pub const Component = struct {
    glyphs: []?Glyph = undefined,
    texture: nux.ID = .null,

    pub fn deinit(self: *Component, mod: *Self) void {
        mod.allocator.free(self.glyphs);
    }

    pub fn getGlyph(self: *const Component, codepoint: u32) ?Glyph {
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
    font.glyphs = try self.allocator.alloc(?Glyph, max + 1);
    errdefer self.allocator.free(font.glyphs);
    for (0..font.glyphs.len) |i| {
        font.glyphs[i] = null;
    }

    // Generate sprite font
    const advance = monogram.width + 1;
    const glyph_width = monogram.width;
    const glyph_height = monogram.height;
    const texture_width = monogram.glyphs.len * glyph_width;
    const texture_height = glyph_height;
    try self.texture.addTransparent(id, texture_width, texture_height);
    const texture = try self.texture.components.get(id);

    var framebuffer = nux.Rasterizer.Framebuffer{
        .pixels = texture.data.?,
        .width = texture_width,
        .height = texture_height,
    };

    // Find min/max char index
    var box: nux.Box2i = .init(0, 0, glyph_width, glyph_height);
    for (monogram.glyphs) |glyph| {

        // Render glyph
        nux.Rasterizer.renderBitmap(
            &framebuffer,
            glyph.bitmap,
            box,
        );

        // Setup glyph
        font.glyphs[@intCast(glyph.char)] = .{
            .box = box,
            .advance = advance,
        };

        // Move to next glyph box
        box.translate(.init(glyph_width, 0));
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
    // Take maximum of each line
    const font = try self.components.get(id);
    var lines = LineIterator.init(text, font, scale, available orelse .maxValue());
    var size: nux.Vec2i = .zero();
    while (lines.next()) |line| {
        size.data[0] = @max(size.x(), line.size.x());
        size.data[1] += line.size.y();
    }
    return size;
}
pub fn render(
    self: *Self,
    id: nux.ID,
    text: []const u8,
    scale: i32,
    alignment: nux.Widget.Alignment,
    available: nux.Vec2i,
) !GlyphIterator {
    const font = try self.components.get(id);
    return .init(text, font, scale, alignment, available);
}
