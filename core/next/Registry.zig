const std = @import("std");
const component = @import("Component.zig");

const Registry = struct {
    components: std.ArrayList(component.ComponentType),
};
