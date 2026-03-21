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

pub fn renderBitmap(fb: Framebuffer, bitmap: []const u8, box: nux.Box2i) void {
    const clipi32 = fb.box().intersect(box) orelse return;
    const clip = clipi32.as(nux.Box2u);

    for (0..clip.size.y()) |row| {
        const dst_y = clip.y() + row;

        for (0..clip.w()) |col| {
            const dst_x = clip.x() + col;

            const isset = ((bitmap[row] >> @intCast(col)) & 1) != 0;
            const dst_index = dst_y * fb.width + dst_x;
            const pi = dst_index * 4;
            const value: u8 = if (isset) 255 else 0;
            fb.pixels[pi + 0] = value;
            fb.pixels[pi + 1] = value;
            fb.pixels[pi + 2] = value;
            fb.pixels[pi + 3] = value;
        }
    }
}
