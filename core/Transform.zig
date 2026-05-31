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

pub fn register(reg: *nux.Registry) !void {
    try reg.addEnum(Self, MyEnum);
    try reg.addFunction(Self, copy);
    try reg.addProperty(Self, .position);
    try reg.addProperty(Self, .scale);
}
pub fn init(self: *Self, core: *nux.Core) !void {
    _ = self;
    _ = core;
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
