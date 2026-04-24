const math = @import("std").math;

pub fn Vec(n: comptime_int, comptime Type: type) type {
    if (n < 1) {
        @compileError("invalid vector dimension");
    }

    return struct {
        const Self = @This();
        pub const T = Type;
        pub const N = n;
        pub const is_integer = (T == i32 or T == u32);

        data: @Vector(n, T),

        const Impl = switch (N) {
            2 => struct {
                fn init(vx: T, vy: T) Self {
                    return .initArray(.{ vx, vy });
                }
            },
            3 => struct {
                fn init(vx: T, vy: T, vz: T) Self {
                    return .initArray(.{ vx, vy, vz });
                }
            },
            4 => struct {
                fn init(vx: T, vy: T, vz: T, vw: T) Self {
                    return .initArray(.{ vx, vy, vz, vw });
                }
            },
            else => unreachable,
        };

        pub const init = Impl.init;

        pub fn initArray(v: [n]T) Self {
            var vec = Self{ .data = undefined };
            inline for (0..n) |i| {
                vec.data[i] = v[i];
            }
            return vec;
        }

        pub fn zero() Self {
            return .scalar(0);
        }

        pub fn scalar(v: T) Self {
            return Self{ .data = @splat(v) };
        }

        pub fn x(self: Self) T {
            return self.data[0];
        }

        pub fn y(self: Self) T {
            return self.data[1];
        }

        pub fn z(self: Self) T {
            return self.data[2];
        }

        pub fn w(self: Self) T {
            return self.data[3];
        }

        pub fn add(self: Self, other: Self) Self {
            return .{ .data = self.data + other.data };
        }

        pub fn addAssign(self: *Self, other: Self) void {
            self.data = self.data + other.data;
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{ .data = self.data - other.data };
        }

        pub fn subAssign(self: *Self, other: Self) void {
            self.data = self.data - other.data;
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{ .data = self.data * other.data };
        }

        pub fn mulAssign(self: *Self, other: Self) void {
            self.data = self.data * other.data;
        }

        pub fn div(self: Self, other: Self) Self {
            return .{ .data = self.data / other.data };
        }

        pub fn divAssign(self: *Self, other: Self) void {
            self.data = self.data / other.data;
        }

        pub fn dot(self: Self, other: Self) T {
            return @reduce(.Add, self.data * other.data);
        }

        pub fn neg(self: Self) Self {
            return self.mul(.scalar(-1));
        }

        pub fn lenSqrt(self: Self) T {
            return self.dot(self);
        }

        pub fn len(self: Self) T {
            return @sqrt(self.lenSqrt());
        }

        pub fn norm(self: Self) Self {
            const magnitude = self.len();
            if (magnitude == 0.0) {
                return self;
            }
            var result: Self = .{ .data = undefined };
            inline for (0..n) |i| {
                result.data[i] = self.data[i] / magnitude;
            }
            return result;
        }

        pub fn distance(self: Self, other: Self) T {
            var sum: T = 0;
            inline for (0..n) |i| {
                const diff = self.data[i] - other.data[i];
                sum += diff * diff;
            }
            return @sqrt(sum);
        }

        pub fn angle(a: Self, b: Self) T {
            const d = a.dot(b);
            const mag = a.len() * b.len();
            return math.acos(d / mag);
        }

        pub fn lerp(a: Self, b: Self, t: T) Self {
            var result: Self = .{ .data = undefined };
            inline for (0..n) |i| {
                result.data[i] = @mulAdd(T, b.data[i] - a.data[i], t, a.data[i]);
            }
            return result;
        }

        pub fn lerpAssign(self: *Self, b: Self, t: T) void {
            inline for (0..n) |i| {
                self.data[i] = @mulAdd(T, b.data[i] - self.data[i], t, self.data[i]);
            }
        }

        pub fn reflect(self: Self, normal: Self) Self {
            const dot_val = self.dot(normal);
            var result: Self = .{ .data = undefined };
            inline for (0..n) |i| {
                result.data[i] = self.data[i] - 2 * dot_val * normal.data[i];
            }
            return result;
        }

        pub fn cross(self: Self, b: Self) Self {
            comptime {
                if (n != 3) {
                    @compileError("cross only defined for 3 dimensional vectors");
                }
            }

            return Self{ .data = .{
                self.data[1] * b.data[2] - self.data[2] * b.data[1],
                self.data[2] * b.data[0] - self.data[0] * b.data[2],
                self.data[0] * b.data[1] - self.data[1] * b.data[0],
            } };
        }

        pub fn max(self: Self, other: Self) Self {
            return .{ .data = @max(self.data, other.data) };
        }

        pub fn min(self: Self, other: Self) Self {
            return .{ .data = @min(self.data, other.data) };
        }

        pub fn as(self: Self, V: type) V {
            var data: @Vector(V.N, V.T) = undefined;
            if (is_integer) {
                if (V.is_integer) {
                    for (0..V.N) |i| data[i] = @intCast(self.data[i]);
                } else {
                    for (0..V.N) |i| data[i] = @floatFromInt(self.data[i]);
                }
            } else {
                if (V.is_integer) {
                    for (0..V.N) |i| data[i] = @intFromFloat(self.data[i]);
                } else {
                    for (0..V.N) |i| data[i] = @floatCast(self.data[i]);
                }
            }
            return V{ .data = data };
        }
    };
}

pub const Vec2 = Vec(2, f32);
pub const Vec3 = Vec(3, f32);
pub const Vec4 = Vec(4, f32);
pub const Vec2d = Vec(2, f64);
pub const Vec3d = Vec(3, f64);
pub const Vec4d = Vec(4, f64);
pub const Vec2i = Vec(2, i32);
pub const Vec3i = Vec(3, i32);
pub const Vec4i = Vec(4, i32);
