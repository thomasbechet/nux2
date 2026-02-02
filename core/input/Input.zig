const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Controller = struct {
    const max: u32 = 4;

    cursor: nux.Vec2,
    cursor_prev: nux.Vec2,
    inputmap: nux.NodeID,
    inputs: std.ArrayList(f32),
    prev_inputs: std.ArrayList(f32),
    // values: std.StringHashMap,
};

pub const State = enum(u32) { pressed = 1, released = 0 };

pub const Key = enum(u32) {
    space = 0,
    apostrophe = 1,
    comma = 2,
    minus = 3,
    period = 4,
    slash = 5,
    num0 = 6,
    num1 = 7,
    num2 = 8,
    num3 = 9,
    num4 = 10,
    num5 = 11,
    num6 = 12,
    num7 = 13,
    num8 = 14,
    num9 = 15,
    semicolon = 16,
    equal = 17,
    a = 18,
    b = 19,
    c = 20,
    d = 21,
    e = 22,
    f = 23,
    g = 24,
    h = 25,
    i = 26,
    j = 27,
    k = 29,
    l = 30,
    m = 31,
    n = 32,
    o = 33,
    p = 34,
    q = 35,
    r = 36,
    s = 37,
    t = 38,
    u = 39,
    v = 40,
    w = 41,
    x = 42,
    y = 43,
    z = 44,
    left_bracket = 45,
    backslash = 46,
    right_bracket = 47,
    grave_accent = 48,
    escape = 49,
    enter = 50,
    tab = 51,
    backspace = 52,
    insert = 53,
    delete = 54,
    right = 55,
    left = 56,
    down = 57,
    up = 58,
    page_up = 59,
    page_down = 60,
    home = 61,
    end = 62,
    caps_lock = 63,
    scroll_lock = 64,
    num_lock = 65,
    print_screen = 66,
    pause = 67,
    f1 = 68,
    f2 = 69,
    f3 = 70,
    f4 = 71,
    f5 = 72,
    f6 = 73,
    f7 = 74,
    f8 = 75,
    f9 = 76,
    f10 = 77,
    f11 = 78,
    f12 = 79,
    f13 = 80,
    f14 = 81,
    f15 = 82,
    f16 = 83,
    f17 = 84,
    f18 = 85,
    f19 = 86,
    f20 = 87,
    f21 = 88,
    f22 = 89,
    f23 = 90,
    f24 = 91,
    f25 = 92,
    kp_0 = 93,
    kp_1 = 94,
    kp_2 = 95,
    kp_3 = 96,
    kp_4 = 97,
    kp_5 = 98,
    kp_6 = 99,
    kp_7 = 100,
    kp_8 = 101,
    kp_9 = 102,
    kp_decimal = 103,
    kp_divide = 104,
    kp_multiply = 105,
    kp_subtract = 106,
    kp_add = 107,
    kp_enter = 108,
    kp_equal = 109,
    left_shift = 110,
    left_control = 111,
    left_alt = 112,
    left_super = 113,
    right_shift = 114,
    right_control = 115,
    right_alt = 116,
    right_super = 117,
    menu = 118,
};

controllers: [Controller.max]Controller,
allocator: std.mem.Allocator,
logger: *nux.Logger,
input_map: *nux.InputMap,
events: std.ArrayList(nux.Platform.Input.Event),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.events = try .initCapacity(self.allocator, 32);
}
pub fn deinit(self: *Self) void {
    self.events.deinit(self.allocator);
}
pub fn onEvent(self: *Self, event: nux.Platform.Input.Event) void {
    self.logger.info("{any} {any}", .{ event.key, event.state });
    self.events.append(self.allocator, event) catch return;
}

// static void
// controller_get_input_value (nux_u32_t       controller,
//                             const nux_c8_t *name,
//                             nux_f32_t      *value,
//                             nux_f32_t      *prev_value,
//                             nux_f32_t       default_value)
// {
//     nux_check(controller < nux_array_size(_module.controllers), goto error);
//     nux_controller_t *ctrl = _module.controllers + controller;
//     nux_inputmap_t   *map
//         = nux_resource_get(NUX_RESOURCE_INPUTMAP, ctrl->inputmap);
//     nux_check(map, goto error);
//     nux_u32_t index;
//     nux_check(nux_inputmap_find_index(map, name, &index), goto error);
//     nux_assert(index < ctrl->inputs.size);
//     *value      = ctrl->inputs.data[index];
//     *prev_value = ctrl->prev_inputs.data[index];
//     return;
// error:
//     *value      = default_value;
//     *prev_value = default_value;
// }

// fn controllerInputValue(self: *Self, controller: u32, name: []const u8, default: f32) struct { f32, f32 } {
//     const missing_default = .{ false, false };
//     if (controller >= Controller.max) return missing_default;
//     const map = self.input_map.objects.get(self.controllers[controller].inputmap) catch return missing_default;
//     // map.entries
// }

pub fn isPressed(self: *Self, controller: u32, name: []const u8) bool {
    _ = controller;
    _ = self;
    _ = name;
    return false;
}
pub fn isReleased(self: *Self, controller: u32, name: []const u8) bool {
    _ = self;
    _ = controller;
    _ = name;
    return false;
}
pub fn isJustPressed(self: *Self, controller: u32, name: []const u8) bool {
    _ = self;
    _ = controller;
    _ = name;
    return false;
}
pub fn isJustReleased(self: *Self, controller: u32, name: []const u8) bool {
    _ = self;
    _ = controller;
    _ = name;
    return false;
}
