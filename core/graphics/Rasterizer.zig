const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

allocator: std.mem.Allocator,
texture: *nux.Texture,
logger: *nux.Logger,

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

    pub fn box(self: *const Framebuffer) nux.Box2i {
        return nux.Box2i.init(
            0,
            0,
            @intCast(self.width),
            @intCast(self.height),
        );
    }
};

const BitIter = struct {
    data: []const u8,
    byte_index: usize = 0,
    bit_index: usize = 0,

    pub fn next(self: *BitIter) ?bool {
        if (self.byte_index >= self.data.len) return null;

        const byte = self.data[self.byte_index];
        const bit = (byte >> @as(u3, @intCast(7 - self.bit_index))) & 1;

        self.bit_index += 1;
        if (self.bit_index == 8) {
            self.bit_index = 0;
            self.byte_index += 1;
        }

        return (bit & 0x1) != 0;
    }
};

pub fn renderBitmap(fb: Framebuffer, bitmap: []const u8, box: nux.Box2i) void {
    const clipi32 = fb.box().intersect(box) orelse return;
    std.log.info("CLIP {}", .{clipi32});
    const clip = clipi32.as(nux.Box2u);
    var bits = BitIter{ .data = bitmap };

    for (0..clip.size.y()) |row| {
        const dst_y = clip.y() + row;

        for (0..clip.w()) |col| {
            const isset = bits.next() orelse return;
            if (!isset) continue;

            const dst_x = clip.x() + col;

            const dst_index = dst_y * fb.width + dst_x;
            const pi = dst_index * 4;
            fb.pixels[pi + 0] = 255;
            fb.pixels[pi + 1] = 255;
            fb.pixels[pi + 2] = 255;
            fb.pixels[pi + 3] = 255;
        }
    }
}
