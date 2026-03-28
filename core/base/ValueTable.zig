const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Component = struct {
    props: std.ArrayList(nux.Property.Type) = .empty,
    values: std.ArrayList(nux.Property.Value) = .empty,

    pub fn properties(self: *const Component) ![]const nux.Property.Type {
        return self.props.items;
    }
};

components: nux.Components(Component),
allocator: nux.Platform.Allocator,
node: *nux.Node,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}

// pub fn getValue(
//     self: *Self,
//     id: nux.ID,
//     name: []const u8,
// ) !nux.Property.Value {}
// pub fn setValue(
//     self: *Self,
//     id: nux.ID,
//     name: []const u8,
//     value: nux.Property.Value,
// ) !void {}
