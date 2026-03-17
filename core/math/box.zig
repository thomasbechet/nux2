const nux = @import("../nux.zig");

pub fn Box(n: comptime_int, comptime T: type) type {
    return struct {
        const Self = @This();
        const ST = if (T == i32)
            u32
        else
            f32;
        pub const N = n;

        pos: @Vector(n, T),
        size: @Vector(n, ST),

        pub fn init(x: T, y: T, w: ST, h: ST) Self {
            return .{
                .pos = .{ x, y },
                .size = .{ w, h },
            };
        }
        pub fn initVector(pos: nux.vec.Vec(N, T), size: nux.vec.Vec(N, ST)) Self {
            return .{
                .pos = pos.data,
                .size = size.data,
            };
        }
        pub fn empty(x: T, y: T) Self {
            return .init(x, y, 0, 0);
        }
        pub fn emptyVector(pos: nux.vec.Vec(N, T)) Self {
            return .initVector(pos, .zero());
        }
    };
}

pub const Box2i = Box(2, i32);
pub const Box3i = Box(3, i32);
pub const Box2f = Box(2, f32);
pub const Box3f = Box(3, f32);
