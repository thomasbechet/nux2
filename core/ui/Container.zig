const nux = @import("../nux.zig");

const Self = @This();

const Component = struct {
    background_color: nux.Color = .red,
};

node: *nux.Node,
components: nux.Components(Component),
