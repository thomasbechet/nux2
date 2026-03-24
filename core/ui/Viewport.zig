const nux = @import("../nux.zig");

const Self = @This();

const Component = struct {
    camera: nux.ID = .null,
};

components: nux.Components(Component),
