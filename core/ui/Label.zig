const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

const Component = struct {
    text: std.ArrayList(u8) = .empty,
    color: nux.Color = .white,

    pub fn deinit(self: *Component, mod: *Self) void {
        self.text.deinit(mod.allocator);
    }
};

allocator: std.mem.Allocator,
components: nux.Components(Component),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

pub fn setText(self: *Self, id: nux.ID, text: []const u8) !void {
    const component = try self.components.get(id);
    component.text.clearRetainingCapacity();
    try component.text.ensureTotalCapacity(self.allocator, text.len);
    component.text.appendSliceAssumeCapacity(text);
}
pub fn setColor(self: *Self, id: nux.ID, color: nux.Color) !void {
    const component = try self.components.get(id);
    component.color = color;
}
