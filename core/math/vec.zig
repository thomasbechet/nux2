const math = @import("std").math;

pub fn Vec(n: comptime_int, comptime T: type) type {
    if (n < 1) {
        @compileError("invalid vector dimension");
    }

    const type_info = @typeInfo(T);
    comptime switch (type_info) {
        .float => {},
        else => @compileError("vec not implemented for type " ++ @typeName(T)),
    };

    return struct {
        const Self = @This();
        pub const N = n;

        data: @Vector(n, T),

        pub fn init(v: [n]T) Self {
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

        pub fn dot(self: Self, other: Self) T {
            var sum: T = 0;
            inline for (0..n) |i| {
                sum += self.data[i] * other.data[i];
            }
            return sum;
        }

        pub fn neg(self: Self) Self {
            return self.mul(.scalar(-1));
        }

        pub fn lenSqrt(self: Self) T {
            return self.dot(self);
        }

        pub fn len(self: Self) T {
            return @sqrt(self.lenSq());
        }

        pub fn norm(self: Self) Self {
            const magnitude = self.len();
            if (magnitude == 0.0) {
                @panic("cannot normalize zero vector");
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
    };
}

pub const Vec2f = Vec(2, f32);
pub const Vec3f = Vec(3, f32);
pub const Vec4f = Vec(4, f32);
pub const Vec2d = Vec(2, f64);
pub const Vec3d = Vec(3, f64);
pub const Vec4d = Vec(4, f64);
