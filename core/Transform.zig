const nux = @import("Core.zig");

const Self = @This();

pub const MyEnum = enum(u32) {
    a,
    b,
    c,
};

objects: nux.Objects(struct {
    position: [3]f32,
    scale: [3]f32,
}),

pub fn configure(reg: *nux.Reg(Self)) !void {
    try reg.enumeration(MyEnum);
}

pub fn init(self: *Self, core: *nux.Core) !void {
    self.objects = try .register(core, .{});
}

pub fn copy(self: *Self, src: nux.ID) !void {
    _ = self;
    _ = src;
}
