const nux = @import("../nux.zig");

pub fn Box(n: comptime_int, comptime T: type) type {
    return struct {
        const Self = @This();
        const Vec = nux.vec.Vec(2, T);

        pub const N = n;
        pub const is_integer = (T == i32 or T == u32);

        pos: Vec,
        size: Vec,

        pub fn init(vx: T, vy: T, vw: T, vh: T) Self {
            return .initVector(
                .init(vx, vy),
                .init(vw, vh),
            );
        }
        pub fn initVector(pos: Vec, size: Vec) Self {
            return .{
                .pos = pos,
                .size = size.max(.zero()),
            };
        }
        pub fn empty(vx: T, vy: T) Self {
            return .init(vx, vy, 0, 0);
        }
        pub fn emptyZero() Self {
            return .empty(0, 0);
        }
        pub fn emptyVector(pos: Vec) Self {
            return .initVector(pos, .zero());
        }
        pub fn translate(self: *Self, t: Vec) void {
            self.pos = self.pos.add(t);
        }
        pub fn x(self: Self) T {
            return self.pos.x();
        }
        pub fn y(self: Self) T {
            return self.pos.y();
        }
        pub fn w(self: Self) T {
            return self.size.x();
        }
        pub fn h(self: Self) T {
            return self.size.y();
        }
        pub fn tl(self: Self) Vec {
            return .init(self.x(), self.y());
        }
        pub fn tr(self: Self) Vec {
            return .init(
                self.x() + @as(T, @intCast(self.w())),
                self.y(),
            );
        }
        pub fn bl(self: Self) Vec {
            return .init(
                self.x(),
                self.y() + @as(T, @intCast(self.h())),
            );
        }
        pub fn br(self: Self) Vec {
            return .init(
                self.x() + @as(T, @intCast(self.w())),
                self.y() + @as(T, @intCast(self.h())),
            );
        }
        pub fn area(self: Self) T {
            return self.w() * self.h();
        }
        pub fn intersect(self: Self, b: Self) ?Self {
            const p1 = self.tl().max(b.tl());
            const p2 = self.br().min(b.br());

            if (p2.x() <= p1.x() or p2.y() <= p1.y()) {
                return null;
            }

            return Self{
                .pos = p1,
                .size = p2.sub(p1).as(Vec),
            };
        }
        pub fn as(self: Self, B: type) B {
            return .{
                .pos = self.pos.as(B.Vec),
                .size = self.size.as(B.Vec),
            };
        }
        pub fn asVec4(self: Self) nux.Vec4 {
            const pos = self.pos.as(nux.Vec2);
            const size = self.size.as(nux.Vec2);
            return .init(pos.x(), pos.y(), size.x(), size.y());
        }
        pub fn fromVec4(v: nux.Vec4) Self {
            if (is_integer) {
                return .init(
                    @intFromFloat(v.x()),
                    @intFromFloat(v.y()),
                    @intFromFloat(v.z()),
                    @intFromFloat(v.w()),
                );
            } else {
                return .init(
                    v.x(),
                    v.y(),
                    v.z(),
                    v.w(),
                );
            }
        }
        pub fn inset(self: Self, distance: nux.Vec4i) Self {
            return .init(
                self.pos.x() + distance.x(),
                self.pos.y() + distance.z(),
                self.size.x() - distance.x() - distance.y(),
                self.size.y() - distance.z() - distance.w(),
            );
        }
    };
}

pub const Box2 = Box(2, f32);
pub const Box3 = Box(3, f32);
pub const Box2i = Box(2, i32);
pub const Box3i = Box(3, i32);
