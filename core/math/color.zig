const nux = @import("../nux.zig");

pub const Color = struct {
    rgba: nux.Vec4,

    pub const white: Color = .init(1, 1, 1, 1);
    pub const red: Color = .init(1, 0, 0, 1);
    pub const green: Color = .init(0, 1, 0, 1);
    pub const blue: Color = .init(0, 0, 1, 1);

    pub fn init(rv: f32, vg: f32, vb: f32, va: f32) Color {
        return .{ .rgba = .init(rv, vg, vb, va) };
    }
    pub fn fromRGBA255(value: [4]f32) Color {
        return .init(
            value[0] / 255,
            value[1] / 255,
            value[2] / 255,
            value[3] / 255,
        );
    }
    pub fn r(self: Color) f32 {
        return self.rgba.x();
    }
    pub fn g(self: Color) f32 {
        return self.rgba.y();
    }
    pub fn b(self: Color) f32 {
        return self.rgba.z();
    }
    pub fn a(self: Color) f32 {
        return self.rgba.w();
    }
};
