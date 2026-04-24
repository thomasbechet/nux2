const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const VirtualCursor = struct {
    const menu_up = "menu.up";
    const menu_down = "menu.down";
    const menu_left = "menu.left";
    const menu_right = "menu.right";

    position: nux.Vec2 = .zero(),
    prev_position: nux.Vec2 = .zero(),
    speed: f32 = 1,

    pub fn wrap(self: *VirtualCursor, position: nux.Vec2) void {
        self.position = position;
        self.prev_position = position;
    }
    pub fn integrate(self: *VirtualCursor, move: nux.Vec2, delta: f32) void {
        self.position.addAssign(move.mul(.scalar(delta)));
    }
};

const Controller = struct {
    const max: u32 = 4;

    inputmap: nux.ID = .null,
    inputs: std.ArrayList(f32) = .empty,
    prev_inputs: std.ArrayList(f32) = .empty,
    cursor: VirtualCursor = .{},

    pub fn ensureSize(self: *Controller, allocator: std.mem.Allocator, size: usize) !void {
        if (size >= self.inputs.items.len) {
            const prev_size = self.inputs.items.len;
            try self.inputs.resize(allocator, size);
            try self.prev_inputs.resize(allocator, size);
            @memset(self.inputs.items[prev_size..], 0);
            @memset(self.prev_inputs.items[prev_size..], 0);
        }
    }
};

pub const State = enum(u32) {
    pressed = 1,
    released = 0,

    pub fn value(self: State) f32 {
        return @floatFromInt(@intFromEnum(self));
    }
};

pub const Input = enum(u32) {

    // Keyboard
    key_space = 0,
    key_apostrophe = 1,
    key_comma = 2,
    key_minus = 3,
    key_period = 4,
    key_slash = 5,
    key_num0 = 6,
    key_num1 = 7,
    key_num2 = 8,
    key_num3 = 9,
    key_num4 = 10,
    key_num5 = 11,
    key_num6 = 12,
    key_num7 = 13,
    key_num8 = 14,
    key_num9 = 15,
    key_semicolon = 16,
    key_equal = 17,
    key_a = 18,
    key_b = 19,
    key_c = 20,
    key_d = 21,
    key_e = 22,
    key_f = 23,
    key_g = 24,
    key_h = 25,
    key_i = 26,
    key_j = 27,
    key_k = 29,
    key_l = 30,
    key_m = 31,
    key_n = 32,
    key_o = 33,
    key_p = 34,
    key_q = 35,
    key_r = 36,
    key_s = 37,
    key_t = 38,
    key_u = 39,
    key_v = 40,
    key_w = 41,
    key_x = 42,
    key_y = 43,
    key_z = 44,
    key_left_bracket = 45,
    key_backslash = 46,
    key_right_bracket = 47,
    key_grave_accent = 48,
    key_escape = 49,
    key_enter = 50,
    key_tab = 51,
    key_backspace = 52,
    key_insert = 53,
    key_delete = 54,
    key_right = 55,
    key_left = 56,
    key_down = 57,
    key_up = 58,
    key_page_up = 59,
    key_page_down = 60,
    key_home = 61,
    key_end = 62,
    key_caps_lock = 63,
    key_scroll_lock = 64,
    key_num_lock = 65,
    key_print_screen = 66,
    key_pause = 67,
    key_f1 = 68,
    key_f2 = 69,
    key_f3 = 70,
    key_f4 = 71,
    key_f5 = 72,
    key_f6 = 73,
    key_f7 = 74,
    key_f8 = 75,
    key_f9 = 76,
    key_f10 = 77,
    key_f11 = 78,
    key_f12 = 79,
    key_f13 = 80,
    key_f14 = 81,
    key_f15 = 82,
    key_f16 = 83,
    key_f17 = 84,
    key_f18 = 85,
    key_f19 = 86,
    key_f20 = 87,
    key_f21 = 88,
    key_f22 = 89,
    key_f23 = 90,
    key_f24 = 91,
    key_f25 = 92,
    key_kp_0 = 93,
    key_kp_1 = 94,
    key_kp_2 = 95,
    key_kp_3 = 96,
    key_kp_4 = 97,
    key_kp_5 = 98,
    key_kp_6 = 99,
    key_kp_7 = 100,
    key_kp_8 = 101,
    key_kp_9 = 102,
    key_kp_decimal = 103,
    key_kp_divide = 104,
    key_kp_multiply = 105,
    key_kp_subtract = 106,
    key_kp_add = 107,
    key_kp_enter = 108,
    key_kp_equal = 109,
    key_left_shift = 110,
    key_left_control = 111,
    key_left_alt = 112,
    key_left_super = 113,
    key_right_shift = 114,
    key_right_control = 115,
    key_right_alt = 116,
    key_right_super = 117,
    key_menu = 118,

    // Mouse Buttons
    mouse_left = 199,
    mouse_right = 200,
    mouse_middle = 201,
    mouse_wheel_up = 202,
    mouse_wheel_down = 203,

    // Mouse Axis
    mouse_motion_right = 204,
    mouse_motion_left = 205,
    mouse_motion_down = 206,
    mouse_motion_up = 207,
    mouse_scroll_up = 208,
    mouse_scroll_down = 209,

    // Gamepad Buttons
    gamepad_a = 210,
    gamepad_x = 211,
    gamepad_y = 212,
    gamepad_b = 213,
    gamepad_dpad_up = 214,
    gamepad_dpad_down = 215,
    gamepad_dpad_left = 216,
    gamepad_dpad_right = 217,
    gamepad_shoulder_left = 218,
    gamepad_shoulder_right = 219,
    gamepad_start = 220,
    gamepad_end = 221,

    // Gamepad Axis
    gamepad_lstick_left = 222,
    gamepad_lstick_right = 223,
    gamepad_lstick_up = 224,
    gamepad_lstick_down = 225,
    gamepad_rstick_left = 226,
    gamepad_rstick_right = 227,
    gamepad_rstick_up = 228,
    gamepad_rstick_down = 229,
    gamepad_ltrigger = 230,
    gamepad_rtrigger = 231,
};

controllers: [Controller.max]Controller,
allocator: std.mem.Allocator,
logger: *nux.Logger,
inputmap: *nux.InputMap,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.controllers = [_]Controller{.{}} ** Controller.max;
}
pub fn deinit(self: *Self) void {
    for (&self.controllers) |*controller| {
        controller.inputs.deinit(self.allocator);
        controller.prev_inputs.deinit(self.allocator);
    }
}
pub fn onEvent(self: *Self, event: *const nux.Platform.Event) void {
    switch (event.*) {
        .inputValueChanged => |e| {

            // Iterate controllers
            for (&self.controllers) |*controller| {
                if (self.inputmap.components.getOptional(controller.inputmap)) |map| {

                    // Iterate map entries
                    for (map.entries.items, 0..) |entry, index| {
                        const mapping = entry.mapping orelse continue;
                        if (mapping == e.input) {

                            // Resize inputs if needed
                            controller.ensureSize(self.allocator, index + 1) catch {};

                            // Assign value
                            controller.inputs.items[index] = e.value;
                        }
                    }
                }
            }
        },
        else => {},
    }
}
pub fn onPreUpdate(self: *Self) !void {

    // Update inputs array size if inputmap has changed
    for (&self.controllers) |*controller| {
        if (self.inputmap.components.getOptional(controller.inputmap)) |map| {
            if (controller.inputs.items.len != map.entries.items.len) {
                try controller.ensureSize(self.allocator, map.entries.items.len);
            }
        }
    }

    // Integrate virtual cursor
    for (&self.controllers, 0..) |*controller, index| {
        const move = self.getVec2(
            @intCast(index),
            VirtualCursor.menu_up,
            VirtualCursor.menu_down,
            VirtualCursor.menu_right,
            VirtualCursor.menu_left,
        );
        controller.cursor.integrate(move, 1.0 / 60.0);
    }
}
pub fn onPostUpdate(self: *Self) !void {

    // Keep previous state
    for (self.controllers) |controller| {
        @memcpy(controller.prev_inputs.items, controller.inputs.items);
    }
}

fn getController(self: *Self, controller: u32) !*Controller {
    if (controller >= Controller.max) {
        return error.InvalidControllerIndex;
    }
    return &self.controllers[controller];
}
fn controllerInputValue(self: *Self, controller: u32, name: []const u8, default: f32) struct { f32, f32 } {
    const default_values = .{ default, default };
    const ctrl = self.getController(controller) catch return default_values;
    const map = self.inputmap.components.get(self.controllers[controller].inputmap) catch return default_values;
    const entry = map.get(name) orelse return default_values;
    if (entry.index >= ctrl.inputs.items.len) {
        return default_values;
    }
    return .{
        ctrl.inputs.items[entry.index],
        ctrl.prev_inputs.items[entry.index],
    };
}

pub fn setMap(self: *Self, controller: u32, id: nux.ID) !void {
    const ctrl = try self.getController(controller);
    ctrl.inputmap = id;
}
pub fn getValue(self: *Self, controller: u32, name: []const u8) f32 {
    const value, _ = self.controllerInputValue(
        controller,
        name,
        0,
    );
    return value;
}
pub fn getVec2(
    self: *Self,
    controller: u32,
    xpos: []const u8,
    xneg: []const u8,
    ypos: []const u8,
    yneg: []const u8,
) nux.Vec2 {
    return .init(
        self.getValue(controller, xpos) - self.getValue(controller, xneg),
        self.getValue(controller, ypos) - self.getValue(controller, yneg),
    );
}
pub fn isPressed(self: *Self, controller: u32, name: []const u8) bool {
    const value, _ = self.controllerInputValue(
        controller,
        name,
        @intFromEnum(State.released),
    );
    return value > @intFromEnum(State.released);
}
pub fn isReleased(self: *Self, controller: u32, name: []const u8) bool {
    return !self.isPressed(controller, name);
}
pub fn isJustPressed(self: *Self, controller: u32, name: []const u8) bool {
    const value, const prev = self.controllerInputValue(
        controller,
        name,
        @intFromEnum(State.released),
    );
    return value > @intFromEnum(State.released) and prev <= @intFromEnum(State.released);
}
pub fn isJustReleased(self: *Self, controller: u32, name: []const u8) bool {
    const value, const prev = self.controllerInputValue(
        controller,
        name,
        @intFromEnum(State.released),
    );
    return value <= @intFromEnum(State.released) and prev > @intFromEnum(State.released);
}
