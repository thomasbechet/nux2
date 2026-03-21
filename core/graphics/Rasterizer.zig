const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

allocator: std.mem.Allocator,
texture: *nux.Texture,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn render(self: *Self, cmds: nux.Graphics.CommandBuffer) !void {
    _ = self;
    _ = cmds;
}

pub const Framebuffer = struct {
    pixels: []u8,
    width: usize,
    height: usize,

    pub fn clip(self: *const Framebuffer, box: nux.Box2i) nux.Box2u {
        return box.clip(.init(0, 0, @intCast(self.width), @intCast(self.height))).as(nux.Box2u);
    }
};

pub fn renderBitmap(fb: Framebuffer, bitmap: []const u8, box: nux.Box2i) void {
    const clip = fb.clip(box);
    const bytes_per_row = (clip.w() + 7) / 8;

    for (0..clip.size.y()) |row| {
        const src_row_offset = row * bytes_per_row;
        const dst_y = clip.y() + row;

        if (dst_y >= fb.height) continue;

        for (0..clip.w()) |col| {
            const byte_index = src_row_offset + (col / 8);
            const bit_index: u3 = @intCast(7 - (col % 8));

            const byte = bitmap[byte_index];
            const bit = (byte >> bit_index) & 1;

            if (bit == 0) continue;

            const dst_x = clip.x() + col;
            if (dst_x >= fb.width) continue;

            const dst_index = dst_y * fb.width + dst_x;

            const i = dst_index * 4;
            fb.pixels[i + 0] = 255;
            fb.pixels[i + 1] = 255;
            fb.pixels[i + 2] = 255;
            fb.pixels[i + 3] = 255;
        }
    }
}
