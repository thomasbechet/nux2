const nux = @import("../nux.zig");

pub fn Box(n: comptime_int, comptime T: type) type {
    return struct {
        const Self = @This();
        const ST = if (T == i32 or T == u32)
            u32
        else
            f32;
        const VP = nux.vec.Vec(n, T);
        const VS = nux.vec.Vec(n, ST);
        pub const N = n;

        pos: VP,
        size: VS,

        pub fn init(vx: T, vy: T, vw: ST, vh: ST) Self {
            return .{
                .pos = .init(vx, vy),
                .size = .init(vw, vh),
            };
        }
        pub fn initVector(pos: VP, size: VS) Self {
            return .{
                .pos = pos,
                .size = size,
            };
        }
        pub fn empty(vx: T, vy: T) Self {
            return .init(vx, vy, 0, 0);
        }
        pub fn emptyVector(pos: VP) Self {
            return .initVector(pos, .zero());
        }
        pub fn translate(self: *Self, t: VP) void {
            self.pos = self.pos.add(t);
        }
        pub fn x(self: Self) T {
            return self.pos.x();
        }
        pub fn y(self: Self) T {
            return self.pos.y();
        }
        pub fn w(self: Self) ST {
            return self.size.x();
        }
        pub fn h(self: Self) ST {
            return self.size.y();
        }
        pub fn tl(self: Self) VP {
            return .init(self.x(), self.y());
        }
        pub fn tr(self: Self) VP {
            return .init(
                self.x() + @as(T, @intCast(self.w())),
                self.y(),
            );
        }
        pub fn bl(self: Self) VP {
            return .init(
                self.x(),
                self.y() + @as(T, @intCast(self.h())),
            );
        }
        pub fn br(self: Self) VP {
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
                .size = p2.sub(p1).as(VS),
            };
        }
        pub fn as(self: Self, B: type) B {
            return .{
                .pos = self.pos.as(B.VP),
                .size = self.size.as(B.VS),
            };
        }
    };
}

pub const Box2 = Box(2, f32);
pub const Box3 = Box(3, f32);
pub const Box2i = Box(2, i32);
pub const Box3i = Box(3, i32);
