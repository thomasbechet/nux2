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

pub fn configure(reg: *nux.Registry) !void {
    try reg.enumeration(Self, MyEnum);
    try reg.function(Self, copy);
    try reg.property(Self, .position);
    try reg.property(Self, .scale);
}
pub fn init(self: *Self, core: *nux.Core) !void {
    self.objects = try .register(core, .{});
}
pub fn deinit(self: *Self) void {
    _ = self;
}
pub fn onUpdate(self: *Self) !void {
    _ = self;
}

pub fn copy(self: *Self, src: nux.ID) !void {
    _ = self;
    _ = src;
}
