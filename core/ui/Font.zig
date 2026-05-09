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
    iterator: std.unicode.Utf8Iterator,

    fn init(text: []const u8, font: *const Component, scale: i32, available: nux.Vec2i) LineIterator {
        return .{
            .text = text,
            .font = font,
            .scale = scale,
            .available = available,
            .iterator = std.unicode.Utf8View.initUnchecked(text).iterator(),
        };
    }

    fn next(self: *LineIterator) ?Line {
        var size: nux.Vec2i = .zero();
        var line_width: i32 = 0;
        var line_height: i32 = 0;
        var was_word: bool = false;
        var line_break: bool = false;
        while (self.iterator.nextCodepoint()) |cp| {
            const glyph = self.font.getGlyph(cp) orelse continue;
            const advance_x = glyph.advance * self.scale;
            const advance_y = glyph.box.h() * self.scale;

            line_width += advance_x;
            line_height = @max(line_height, advance_y);

            // Detect wrap
            if (line_width > self.available.x()) {
                line_break = true;
                break;
            }

            // Detect end of word
            const is_word = cp != ' ';
            if (!is_word and was_word) {
                size.data[0] = line_width;
                size.data[1] = line_height;
            }
            was_word = is_word;
        }

        if (!line_break) {
            size.data[0] = line_width;
            size.data[1] = line_height;
        }

        return .{
            .iterator = undefined,
            .size = size,
        };
    }
};

pub const GlyphIterator = struct {
    const Item = struct {
        position: nux.Vec2i,
        glyph: Component.Glyph,
        advance_x: i32,
        advance_y: i32,
    };

    lines: LineIterator,
    line: ?LineIterator.Line,
    cursor: nux.Vec2i = .zero(),

    fn init(text: []const u8, font: *const Component, scale: i32, available: nux.Vec2i) GlyphIterator {
        return .{
            .lines = .init(text, font, scale, available),
        };
    }

    pub fn next(self: *GlyphIterator) ?Item {
        while (true) {

            // Fetch line
            if (self.line == null) {
                self.line = self.line_iterator.next();
                if (self.line == null) {
                    return null;
                }
            }
            const line = &self.line.?;

            // Check end of available height
            if (self.cursor.y() + line.height > self.available.y()) {
                return null;
            }

            if (line.iterator.nextCodepoint()) |codepoint| {
                // Fetch glyph
                const glyph = self.font.getGlyph(codepoint) orelse continue;
                const advance = glyph.advance * self.scale;

                const item = Item{
                    .glyph = glyph,
                    .position = self.cursor,
                    .advance_x = advance,
                    .advance_y = self.line.?.height,
                };

                // Update cursor position
                self.cursor.data[0] += advance;

                return item;
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
    var size: nux.Vec2i = .zero();
    var it = LineIterator.init(text, font, scale, available);
    while (it.next()) |line| {
        size.data[0] = @max(size.x(), line.width);
        size.data[1] += line.height;
    }
    return size;
}
