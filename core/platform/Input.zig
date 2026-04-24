const nux = @import("../nux.zig");

pub const InputValueChanged = struct {
    input: nux.Input.Input,
    value: f32, // Use Input.State for pressed / released
};

pub const MouseMoved = struct {
    position: nux.Vec2, 
};
