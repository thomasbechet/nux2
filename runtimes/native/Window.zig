const c = @cImport({
    @cInclude("glfw3.h");
});
const builtin = @import("builtin");
const nux = @import("nux");
const gl = @import("gl");
const std = @import("std");

const gamepadcontrollerdb = @embedFile("gamecontrollerdb.txt");

var procs: gl.ProcTable = undefined;
var key_map: [c.GLFW_KEY_LAST + 1]?nux.Input.Input = undefined;
var mouse_button_map: [c.GLFW_MOUSE_BUTTON_LAST + 1]?nux.Input.Input = undefined;
var gamepad_button_map: [c.GLFW_GAMEPAD_BUTTON_LAST + 1]?nux.Input.Input = undefined;
var gamepad_axis_map: [c.GLFW_GAMEPAD_AXIS_LAST + 1]?nux.Input.Input = undefined;

const Self = @This();

const Size = struct {
    w: gl.int = 0,
    h: gl.int = 0,
};

window: ?*c.GLFWwindow = null,
core: *nux.Core = undefined, // Keep temporary reference during callbacks
switch_fullscreen: bool = false,
fullscreen: bool = false,
prev_position: struct {
    x: c_int = 0,
    y: c_int = 0,
} = .{},
prev_size: Size = .{},
size: Size = .{},

fn glMessageCallback(source: gl.@"enum", @"type": gl.@"enum", id: gl.uint, severity: gl.@"enum", length: gl.sizei, message: [*:0]const gl.char, userParam: ?*const anyopaque) callconv(gl.APIENTRY) void {
    if (@"type" == gl.DEBUG_TYPE_OTHER) {
        return;
    }
    _ = id;
    _ = severity;
    _ = source;
    _ = length;
    _ = userParam;
    const msg = std.mem.span(message);
    std.log.err("{s}", .{msg});
}

fn open(ctx: *anyopaque, w: u32, h: u32) anyerror!void {
    var self: *Self = @ptrCast(@alignCast(ctx));

    // Create window
    if (builtin.os.tag == .linux) { // Force X11 on linux
        c.glfwInitHint(c.GLFW_PLATFORM, c.GLFW_PLATFORM_X11);
    }
    if (c.glfwInit() == 0) {
        @panic("Failed to initialize GLFW");
    }
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_SAMPLES, 0);
    self.window = c.glfwCreateWindow(@intCast(w), @intCast(h), "nux", null, null);
    c.glfwSetWindowSize(self.window, @intCast(w), @intCast(h));
    c.glfwGetFramebufferSize(self.window, &self.size.w, &self.size.h);

    // Init opengl
    c.glfwMakeContextCurrent(self.window);
    gl.makeProcTableCurrent(&procs);
    if (!procs.init(c.glfwGetProcAddress)) return error.initFailed;
    gl.Enable(gl.DEBUG_OUTPUT);
    gl.DebugMessageCallback(glMessageCallback, null);

    // Setup gamepad
    _ = c.glfwUpdateGamepadMappings(gamepadcontrollerdb);

    // Setup callbacks
    _ = c.glfwSetFramebufferSizeCallback(self.window, resizeCallback);
    _ = c.glfwSetKeyCallback(self.window, keyCallback);
    c.glfwSetWindowUserPointer(self.window, @ptrCast(self));
}
fn close(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.deinit();
}
fn resize(_: *anyopaque, _: u32, _: u32) void {}

pub fn init() Self {
    key_map[c.GLFW_KEY_SPACE] = .key_space;
    key_map[c.GLFW_KEY_APOSTROPHE] = .key_apostrophe;
    key_map[c.GLFW_KEY_COMMA] = .key_comma;
    key_map[c.GLFW_KEY_MINUS] = .key_minus;
    key_map[c.GLFW_KEY_PERIOD] = .key_period;
    key_map[c.GLFW_KEY_SLASH] = .key_slash;
    key_map[c.GLFW_KEY_0] = .key_num0;
    key_map[c.GLFW_KEY_1] = .key_num1;
    key_map[c.GLFW_KEY_2] = .key_num2;
    key_map[c.GLFW_KEY_3] = .key_num3;
    key_map[c.GLFW_KEY_4] = .key_num4;
    key_map[c.GLFW_KEY_5] = .key_num5;
    key_map[c.GLFW_KEY_6] = .key_num6;
    key_map[c.GLFW_KEY_7] = .key_num7;
    key_map[c.GLFW_KEY_8] = .key_num8;
    key_map[c.GLFW_KEY_9] = .key_num9;
    key_map[c.GLFW_KEY_SEMICOLON] = .key_semicolon;
    key_map[c.GLFW_KEY_EQUAL] = .key_equal;
    key_map[c.GLFW_KEY_A] = .key_a;
    key_map[c.GLFW_KEY_B] = .key_b;
    key_map[c.GLFW_KEY_C] = .key_c;
    key_map[c.GLFW_KEY_D] = .key_d;
    key_map[c.GLFW_KEY_E] = .key_e;
    key_map[c.GLFW_KEY_F] = .key_f;
    key_map[c.GLFW_KEY_G] = .key_g;
    key_map[c.GLFW_KEY_H] = .key_h;
    key_map[c.GLFW_KEY_I] = .key_i;
    key_map[c.GLFW_KEY_J] = .key_j;
    key_map[c.GLFW_KEY_K] = .key_k;
    key_map[c.GLFW_KEY_L] = .key_l;
    key_map[c.GLFW_KEY_M] = .key_m;
    key_map[c.GLFW_KEY_N] = .key_n;
    key_map[c.GLFW_KEY_O] = .key_o;
    key_map[c.GLFW_KEY_P] = .key_p;
    key_map[c.GLFW_KEY_Q] = .key_q;
    key_map[c.GLFW_KEY_R] = .key_r;
    key_map[c.GLFW_KEY_S] = .key_s;
    key_map[c.GLFW_KEY_T] = .key_t;
    key_map[c.GLFW_KEY_U] = .key_u;
    key_map[c.GLFW_KEY_V] = .key_v;
    key_map[c.GLFW_KEY_W] = .key_w;
    key_map[c.GLFW_KEY_X] = .key_x;
    key_map[c.GLFW_KEY_Y] = .key_y;
    key_map[c.GLFW_KEY_Z] = .key_z;
    key_map[c.GLFW_KEY_LEFT_BRACKET] = .key_left_bracket;
    key_map[c.GLFW_KEY_BACKSLASH] = .key_backslash;
    key_map[c.GLFW_KEY_RIGHT_BRACKET] = .key_right_bracket;
    key_map[c.GLFW_KEY_GRAVE_ACCENT] = .key_grave_accent;
    key_map[c.GLFW_KEY_WORLD_1] = null;
    key_map[c.GLFW_KEY_WORLD_2] = null;
    key_map[c.GLFW_KEY_ESCAPE] = .key_escape;
    key_map[c.GLFW_KEY_ENTER] = .key_enter;
    key_map[c.GLFW_KEY_TAB] = .key_tab;
    key_map[c.GLFW_KEY_BACKSPACE] = .key_backspace;
    key_map[c.GLFW_KEY_INSERT] = .key_insert;
    key_map[c.GLFW_KEY_DELETE] = .key_delete;
    key_map[c.GLFW_KEY_RIGHT] = .key_right;
    key_map[c.GLFW_KEY_LEFT] = .key_left;
    key_map[c.GLFW_KEY_DOWN] = .key_down;
    key_map[c.GLFW_KEY_UP] = .key_up;
    key_map[c.GLFW_KEY_PAGE_UP] = .key_page_up;
    key_map[c.GLFW_KEY_PAGE_DOWN] = .key_page_down;
    key_map[c.GLFW_KEY_HOME] = .key_home;
    key_map[c.GLFW_KEY_END] = .key_end;
    key_map[c.GLFW_KEY_CAPS_LOCK] = .key_caps_lock;
    key_map[c.GLFW_KEY_SCROLL_LOCK] = .key_scroll_lock;
    key_map[c.GLFW_KEY_NUM_LOCK] = .key_num_lock;
    key_map[c.GLFW_KEY_PRINT_SCREEN] = .key_print_screen;
    key_map[c.GLFW_KEY_PAUSE] = .key_pause;
    key_map[c.GLFW_KEY_F1] = .key_f1;
    key_map[c.GLFW_KEY_F2] = .key_f2;
    key_map[c.GLFW_KEY_F3] = .key_f3;
    key_map[c.GLFW_KEY_F4] = .key_f4;
    key_map[c.GLFW_KEY_F5] = .key_f5;
    key_map[c.GLFW_KEY_F6] = .key_f6;
    key_map[c.GLFW_KEY_F7] = .key_f7;
    key_map[c.GLFW_KEY_F8] = .key_f8;
    key_map[c.GLFW_KEY_F9] = .key_f9;
    key_map[c.GLFW_KEY_F10] = .key_f10;
    key_map[c.GLFW_KEY_F11] = .key_f11;
    key_map[c.GLFW_KEY_F12] = .key_f12;
    key_map[c.GLFW_KEY_F13] = .key_f13;
    key_map[c.GLFW_KEY_F14] = .key_f14;
    key_map[c.GLFW_KEY_F15] = .key_f15;
    key_map[c.GLFW_KEY_F16] = .key_f16;
    key_map[c.GLFW_KEY_F17] = .key_f17;
    key_map[c.GLFW_KEY_F18] = .key_f18;
    key_map[c.GLFW_KEY_F19] = .key_f19;
    key_map[c.GLFW_KEY_F20] = .key_f20;
    key_map[c.GLFW_KEY_F21] = .key_f21;
    key_map[c.GLFW_KEY_F22] = .key_f22;
    key_map[c.GLFW_KEY_F23] = .key_f23;
    key_map[c.GLFW_KEY_F24] = .key_f24;
    key_map[c.GLFW_KEY_F25] = .key_f25;
    key_map[c.GLFW_KEY_KP_0] = .key_kp_0;
    key_map[c.GLFW_KEY_KP_1] = .key_kp_1;
    key_map[c.GLFW_KEY_KP_2] = .key_kp_2;
    key_map[c.GLFW_KEY_KP_3] = .key_kp_3;
    key_map[c.GLFW_KEY_KP_4] = .key_kp_4;
    key_map[c.GLFW_KEY_KP_5] = .key_kp_5;
    key_map[c.GLFW_KEY_KP_6] = .key_kp_6;
    key_map[c.GLFW_KEY_KP_7] = .key_kp_7;
    key_map[c.GLFW_KEY_KP_8] = .key_kp_8;
    key_map[c.GLFW_KEY_KP_9] = .key_kp_9;
    key_map[c.GLFW_KEY_KP_DECIMAL] = .key_kp_decimal;
    key_map[c.GLFW_KEY_KP_DIVIDE] = .key_kp_divide;
    key_map[c.GLFW_KEY_KP_MULTIPLY] = .key_kp_multiply;
    key_map[c.GLFW_KEY_KP_SUBTRACT] = .key_kp_subtract;
    key_map[c.GLFW_KEY_KP_ADD] = .key_kp_add;
    key_map[c.GLFW_KEY_KP_ENTER] = .key_kp_enter;
    key_map[c.GLFW_KEY_KP_EQUAL] = .key_kp_equal;
    key_map[c.GLFW_KEY_LEFT_SHIFT] = .key_left_shift;
    key_map[c.GLFW_KEY_LEFT_CONTROL] = .key_left_control;
    key_map[c.GLFW_KEY_LEFT_ALT] = .key_left_alt;
    key_map[c.GLFW_KEY_LEFT_SUPER] = .key_left_super;
    key_map[c.GLFW_KEY_RIGHT_SHIFT] = .key_right_shift;
    key_map[c.GLFW_KEY_RIGHT_CONTROL] = .key_right_control;
    key_map[c.GLFW_KEY_RIGHT_ALT] = .key_right_alt;
    key_map[c.GLFW_KEY_RIGHT_SUPER] = .key_right_super;
    key_map[c.GLFW_KEY_MENU] = .key_menu;

    mouse_button_map[c.GLFW_MOUSE_BUTTON_LEFT] = .mouse_left;
    mouse_button_map[c.GLFW_MOUSE_BUTTON_RIGHT] = .mouse_right;
    mouse_button_map[c.GLFW_MOUSE_BUTTON_MIDDLE] = .mouse_middle;

    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_A] = .gamepad_a;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_B] = .gamepad_b;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_X] = .gamepad_x;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_Y] = .gamepad_y;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_LEFT_BUMPER] = .gamepad_shoulder_left;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_RIGHT_BUMPER] = .gamepad_shoulder_right;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_BACK] = .gamepad_start;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_START] = .gamepad_end;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_DPAD_UP] = .gamepad_dpad_up;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_DPAD_RIGHT] = .gamepad_dpad_right;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_DPAD_DOWN] = .gamepad_dpad_down;
    gamepad_button_map[c.GLFW_GAMEPAD_BUTTON_DPAD_LEFT] = .gamepad_dpad_left;

    gamepad_axis_map[c.GLFW_GAMEPAD_AXIS_RIGHT_X] = .gamepad_rstick_right;

    return .{};
}
pub fn deinit(self: *Self) void {
    if (self.window != null) {
        gl.makeProcTableCurrent(null);
        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();
    }
}
pub fn platform(self: *Self) nux.Platform.Window {
    return .{ .ptr = self, .vtable = &.{
        .open = open,
        .close = close,
        .resize = resize,
    } };
}
pub fn pollEvents(self: *Self, core: *nux.Core) !void {
    if (self.window) |window| {
        self.core = core;
        c.glfwPollEvents();
        if (c.glfwWindowShouldClose(window) != 0) {
            core.pushEvent(.requestExit);
        }

        // Acquire gamepads inputs
        for (c.GLFW_JOYSTICK_1..c.GLFW_JOYSTICK_LAST) |joystick_index| {
            const jid: c_int = @intCast(joystick_index);
            std.log.info("TEST {d} {d} {d}", .{ joystick_index, c.glfwJoystickPresent(jid), c.glfwJoystickIsGamepad(jid) });
            if (c.glfwJoystickPresent(jid) != 0 and c.glfwJoystickIsGamepad(jid) != 0) {
                var state: c.GLFWgamepadstate = undefined;
                if (c.glfwGetGamepadState(jid, &state) != 0) {
                    std.log.info("OK", .{});
                    for (0..c.GLFW_GAMEPAD_BUTTON_LAST) |button_index| {
                        _ = button_index;
                        // nux_button_t mask = gamepad_button_to_button(button);
                        // if (mask != (nux_button_t)-1)
                        // {
                        //     if (state.buttons[button])
                        //     {
                        //         runtime.buttons |= mask;
                        //     }
                        //     else
                        //     {
                        //         runtime.buttons &= ~mask;
                        //     }
                        // }
                    }

                    for (0..c.GLFW_GAMEPAD_AXIS_LAST) |axis_index| {
                        if (gamepad_axis_map[axis_index]) |axis| {
                            var value: f32 = state.axes[axis_index];
                            if (@abs(value) <= 0.3) {
                                value = 0;
                            }
                            if (axis_index == c.GLFW_GAMEPAD_AXIS_RIGHT_Y or axis_index == c.GLFW_GAMEPAD_AXIS_LEFT_Y) {
                                value = -value;
                            }

                            core.pushEvent(.{ .inputValueChanged = .{
                                .input = axis,
                                .value = value,
                            } });
                        }
                    }
                }
            }
        }
    }
}
fn checkFullscreen(self: *Self) void {
    if (self.switch_fullscreen) {
        if (self.fullscreen) {
            c.glfwSetWindowMonitor(
                self.window,
                null,
                self.prev_position.x,
                self.prev_position.y,
                self.prev_size.w,
                self.prev_size.h,
                0,
            );
        } else {
            const mon: ?*c.GLFWmonitor = c.glfwGetPrimaryMonitor();
            const mode: ?*const c.GLFWvidmode = c.glfwGetVideoMode(c.glfwGetPrimaryMonitor());
            c.glfwSetWindowMonitor(
                self.window,
                mon,
                0,
                0,
                mode.?.width,
                mode.?.height,
                mode.?.refreshRate,
            );
            var xpos: gl.int = 0;
            var ypos: gl.int = 0;
            c.glfwGetWindowPos(self.window, &xpos, &ypos);
            self.prev_position = .{ .x = xpos, .y = ypos };
            self.prev_size = .{ .w = 500, .h = 500 };
        }
        self.switch_fullscreen = false;
        self.fullscreen = !self.fullscreen;
    }
}
pub fn swapBuffers(self: *Self) !void {
    self.checkFullscreen();
    if (self.window) |window| {
        c.glfwSwapBuffers(window);
    }
}

fn resizeCallback(win: ?*c.GLFWwindow, w: c_int, h: c_int) callconv(.c) void {
    const self: *Self = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(win).?));
    self.size.w = w;
    self.size.h = h;
    self.core.pushEvent(.{
        .windowResized = .{ .width = @intCast(w), .height = @intCast(h) },
    });
}
fn keyCallback(win: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = scancode;
    _ = mods;
    const self: *Self = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(win).?));
    switch (key) {
        c.GLFW_KEY_ESCAPE => {
            self.core.pushEvent(.requestExit);
        },
        c.GLFW_KEY_F11 => {
            if (action == c.GLFW_RELEASE) {
                self.switch_fullscreen = true;
            }
        },
        else => {},
    }
    const state: nux.Input.State = if (action == c.GLFW_RELEASE) .released else .pressed;
    if (key_map[@intCast(key)]) |input| {
        self.core.pushEvent(.{ .inputValueChanged = .{
            .input = input,
            .value = @floatFromInt(@intFromEnum(state)),
        } });
    }
}
