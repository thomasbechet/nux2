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
    width: i32,
    height: i32,

    pub fn box(self: *const Framebuffer) nux.Box2i {
        return nux.Box2i.init(
            0,
            0,
            @intCast(self.width),
            @intCast(self.height),
        );
    }

    pub fn setColor(self: *Framebuffer, x: i32, y: i32, color: nux.Color) void {
        const pi: i32 = (y * self.width + x) * 4;
        if (pi >= self.pixels.len) return;
        const index: usize = @intCast(pi);
        const rgba = color.toRGBA255();
        self.pixels[index + 0] = rgba.r;
        self.pixels[index + 1] = rgba.g;
        self.pixels[index + 2] = rgba.b;
        self.pixels[index + 3] = rgba.a;
    }
};

pub fn renderBitmap(fb: *Framebuffer, bitmap: []const u8, box: nux.Box2i) void {
    const clip = fb.box().intersect(box) orelse return;

    for (0..@intCast(clip.size.y())) |row| {
        const dst_y = clip.y() + @as(i32, @intCast(row));

        for (0..@intCast(clip.w())) |col| {
            const dst_x = clip.x() + @as(i32, @intCast(col));

            const isset = ((bitmap[row] >> @intCast(col)) & 1) != 0;
            if (isset) {
                fb.setColor(dst_x, dst_y, .white);
            }
        }
    }
}
