const nux = @import("../nux.zig");

pub const Event = struct {
    key: nux.Input.Key,
    state: nux.Input.State,
};
