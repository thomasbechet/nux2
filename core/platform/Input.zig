const nux = @import("../nux.zig");

pub const InputValueChanged = struct {
    button: nux.Input.Button,
    value: f32, // Use Input.State for pressed / released
};
