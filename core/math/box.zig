pub fn Box(n: comptime_int, comptime T: type) type {
    return struct {
        const Self = @This();
        pub const N = n;

        pos: @Vector(n, T),
        size: @Vector(n, u32),
    };
}

pub const Box2i = Box(2, i32);
