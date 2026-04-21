const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Controller = struct {
    const max: u32 = 4;

    cursor: nux.Vec2 = .zero(),
    cursor_prev: nux.Vec2 = .zero(),
    inputmap: nux.ID = .null,
    inputs: std.ArrayList(f32) = .empty,
    prev_inputs: std.ArrayList(f32) = .empty,
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

pub const MouseButton = enum(u32) {
    left = 0,
    right = 1,
    middle = 2,
    wheel_up = 3,
    wheel_down = 4,
};

pub const MouseAxis = enum(u32) {
    motion_right = 0,
    motion_left = 1,
    motion_down = 2,
    motion_up = 3,
    scroll_up = 4,
    scroll_down = 5,
};

pub const GamepadButton = enum(u32) {
    a = 0,
    x = 1,
    y = 2,
    b = 3,
    dpad_up = 4,
    dpad_down = 5,
    dpad_left = 6,
    dpad_right = 7,
    shoulder_left = 8,
    shoulder_right = 9,
};

pub const GamepadAxis = enum(u32) {
    lstick_left = 0,
    lstick_right = 1,
    lstick_up = 2,
    lstick_down = 3,
    rstick_left = 4,
    rstick_right = 5,
    rstick_up = 6,
    rstick_down = 7,
    ltrigger = 8,
    rtrigger = 9,
};

pub const Input = union(enum) {
    key: Key,
    mouse_button: MouseButton,
    gamepad_button: GamepadButton,
    mouse_axis: MouseAxis,
    gamepad_axis: GamepadAxis,
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

        },
        else => {}
    }

    // Iterate controllers
    for (self.controllers) |controller| {
        if (self.inputmap.components.getOptional(controller.inputmap)) |map| {

            // Iterate map entries
            for (map.entries.items, 0..) |entry, index| {
                const mapping = entry.mapping orelse continue;

                // Check mapping
                switch (event.*) {
                    .buttonStateChanged => |e| {
                        switch (e.button) {
                            .key => |k| {
                                if (mapping == .key and mapping.key == k) {}
                            },
                            .gamepad => |g| {},
                        }
                    },
                    .axisValueChanged => |e| {},
                    else => {},
                }
                if (mapping == .key and event.* == .keyStateChanged) {
                    if (event.keyStateChanged.key == mapping.key) {
                        controller.inputs.items[index] = @floatFromInt(@intFromEnum(event.keyStateChanged.state));
                    }
                } else if (mapping == .mouse_button and event.* == .mouseButtonStateChanged) {
                    if (event.keyStateChanged.key == mapping.key) {
                        controller.inputs.items[index] = @floatFromInt(@intFromEnum(event.keyStateChanged.state));
                    }
                }
            }
        }
    }
}
pub fn onPreUpdate(self: *Self) !void {

    // Update inputs array size if inputmap has changed
    for (&self.controllers) |*controller| {
        if (self.inputmap.components.getOptional(controller.inputmap)) |map| {
            if (controller.inputs.items.len != map.entries.items.len) {
                try controller.inputs.resize(self.allocator, map.entries.items.len);
                try controller.prev_inputs.resize(self.allocator, map.entries.items.len);
            }
        }
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

pub fn setInputMap(self: *Self, controller: u32, id: nux.ID) !void {
    const ctrl = try self.getController(controller);
    ctrl.inputmap = id;
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
