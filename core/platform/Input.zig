const nux = @import("../nux.zig");

pub const KeyPressed = struct {
    key: nux.Input.Key,
    state: nux.Input.State,
};
