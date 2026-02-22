const c = @cImport({
    @cInclude("glfw3.h");
});
const builtin = @import("builtin");
const nux = @import("nux");
const gl = @import("gl");

var procs: gl.ProcTable = undefined;
var key_map: [c.GLFW_KEY_LAST + 1]?nux.Input.Key = undefined;

const Self = @This();

window: ?*c.GLFWwindow = null,
core: *nux.Core = undefined,

fn open(ctx: *anyopaque, w: u32, h: u32) anyerror!void {
    var self: *Self = @ptrCast(@alignCast(ctx));
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

    const cw: c_int = @intCast(w);
    const ch: c_int = @intCast(h);
    self.window = c.glfwCreateWindow(cw, ch, "nux", null, null);
    c.glfwSetWindowSize(self.window, cw, ch);
    c.glfwMakeContextCurrent(self.window);

    gl.makeProcTableCurrent(&procs);
    if (!procs.init(c.glfwGetProcAddress)) return error.initFailed;

    _ = c.glfwSetKeyCallback(self.window, keyCallback);
    c.glfwSetWindowUserPointer(self.window, @ptrCast(self));
}
fn close(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.deinit();
}
fn resize(_: *anyopaque, _: u32, _: u32) anyerror!void {}

pub fn init() Self {
    key_map[c.GLFW_KEY_SPACE] = .space;
    key_map[c.GLFW_KEY_SPACE] = .space;
    key_map[c.GLFW_KEY_APOSTROPHE] = .apostrophe;
    key_map[c.GLFW_KEY_COMMA] = .comma;
    key_map[c.GLFW_KEY_MINUS] = .minus;
    key_map[c.GLFW_KEY_PERIOD] = .period;
    key_map[c.GLFW_KEY_SLASH] = .slash;
    key_map[c.GLFW_KEY_0] = .num0;
    key_map[c.GLFW_KEY_1] = .num1;
    key_map[c.GLFW_KEY_2] = .num2;
    key_map[c.GLFW_KEY_3] = .num3;
    key_map[c.GLFW_KEY_4] = .num4;
    key_map[c.GLFW_KEY_5] = .num5;
    key_map[c.GLFW_KEY_6] = .num6;
    key_map[c.GLFW_KEY_7] = .num7;
    key_map[c.GLFW_KEY_8] = .num8;
    key_map[c.GLFW_KEY_9] = .num9;
    key_map[c.GLFW_KEY_SEMICOLON] = .semicolon;
    key_map[c.GLFW_KEY_EQUAL] = .equal;
    key_map[c.GLFW_KEY_A] = .a;
    key_map[c.GLFW_KEY_B] = .b;
    key_map[c.GLFW_KEY_C] = .c;
    key_map[c.GLFW_KEY_D] = .d;
    key_map[c.GLFW_KEY_E] = .e;
    key_map[c.GLFW_KEY_F] = .f;
    key_map[c.GLFW_KEY_G] = .g;
    key_map[c.GLFW_KEY_H] = .h;
    key_map[c.GLFW_KEY_I] = .i;
    key_map[c.GLFW_KEY_J] = .j;
    key_map[c.GLFW_KEY_K] = .k;
    key_map[c.GLFW_KEY_L] = .l;
    key_map[c.GLFW_KEY_M] = .m;
    key_map[c.GLFW_KEY_N] = .n;
    key_map[c.GLFW_KEY_O] = .o;
    key_map[c.GLFW_KEY_P] = .p;
    key_map[c.GLFW_KEY_Q] = .q;
    key_map[c.GLFW_KEY_R] = .r;
    key_map[c.GLFW_KEY_S] = .s;
    key_map[c.GLFW_KEY_T] = .t;
    key_map[c.GLFW_KEY_U] = .u;
    key_map[c.GLFW_KEY_V] = .v;
    key_map[c.GLFW_KEY_W] = .w;
    key_map[c.GLFW_KEY_X] = .x;
    key_map[c.GLFW_KEY_Y] = .y;
    key_map[c.GLFW_KEY_Z] = .z;
    key_map[c.GLFW_KEY_LEFT_BRACKET] = .left_bracket;
    key_map[c.GLFW_KEY_BACKSLASH] = .backslash;
    key_map[c.GLFW_KEY_RIGHT_BRACKET] = .right_bracket;
    key_map[c.GLFW_KEY_GRAVE_ACCENT] = .grave_accent;
    key_map[c.GLFW_KEY_WORLD_1] = null;
    key_map[c.GLFW_KEY_WORLD_2] = null;
    key_map[c.GLFW_KEY_ESCAPE] = .escape;
    key_map[c.GLFW_KEY_ENTER] = .enter;
    key_map[c.GLFW_KEY_TAB] = .tab;
    key_map[c.GLFW_KEY_BACKSPACE] = .backspace;
    key_map[c.GLFW_KEY_INSERT] = .insert;
    key_map[c.GLFW_KEY_DELETE] = .delete;
    key_map[c.GLFW_KEY_RIGHT] = .right;
    key_map[c.GLFW_KEY_LEFT] = .left;
    key_map[c.GLFW_KEY_DOWN] = .down;
    key_map[c.GLFW_KEY_UP] = .up;
    key_map[c.GLFW_KEY_PAGE_UP] = .page_up;
    key_map[c.GLFW_KEY_PAGE_DOWN] = .page_down;
    key_map[c.GLFW_KEY_HOME] = .home;
    key_map[c.GLFW_KEY_END] = .end;
    key_map[c.GLFW_KEY_CAPS_LOCK] = .caps_lock;
    key_map[c.GLFW_KEY_SCROLL_LOCK] = .scroll_lock;
    key_map[c.GLFW_KEY_NUM_LOCK] = .num_lock;
    key_map[c.GLFW_KEY_PRINT_SCREEN] = .print_screen;
    key_map[c.GLFW_KEY_PAUSE] = .pause;
    key_map[c.GLFW_KEY_F1] = .f1;
    key_map[c.GLFW_KEY_F2] = .f2;
    key_map[c.GLFW_KEY_F3] = .f3;
    key_map[c.GLFW_KEY_F4] = .f4;
    key_map[c.GLFW_KEY_F5] = .f5;
    key_map[c.GLFW_KEY_F6] = .f6;
    key_map[c.GLFW_KEY_F7] = .f7;
    key_map[c.GLFW_KEY_F8] = .f8;
    key_map[c.GLFW_KEY_F9] = .f9;
    key_map[c.GLFW_KEY_F10] = .f10;
    key_map[c.GLFW_KEY_F11] = .f11;
    key_map[c.GLFW_KEY_F12] = .f12;
    key_map[c.GLFW_KEY_F13] = .f13;
    key_map[c.GLFW_KEY_F14] = .f14;
    key_map[c.GLFW_KEY_F15] = .f15;
    key_map[c.GLFW_KEY_F16] = .f16;
    key_map[c.GLFW_KEY_F17] = .f17;
    key_map[c.GLFW_KEY_F18] = .f18;
    key_map[c.GLFW_KEY_F19] = .f19;
    key_map[c.GLFW_KEY_F20] = .f20;
    key_map[c.GLFW_KEY_F21] = .f21;
    key_map[c.GLFW_KEY_F22] = .f22;
    key_map[c.GLFW_KEY_F23] = .f23;
    key_map[c.GLFW_KEY_F24] = .f24;
    key_map[c.GLFW_KEY_F25] = .f25;
    key_map[c.GLFW_KEY_KP_0] = .kp_0;
    key_map[c.GLFW_KEY_KP_1] = .kp_1;
    key_map[c.GLFW_KEY_KP_2] = .kp_2;
    key_map[c.GLFW_KEY_KP_3] = .kp_3;
    key_map[c.GLFW_KEY_KP_4] = .kp_4;
    key_map[c.GLFW_KEY_KP_5] = .kp_5;
    key_map[c.GLFW_KEY_KP_6] = .kp_6;
    key_map[c.GLFW_KEY_KP_7] = .kp_7;
    key_map[c.GLFW_KEY_KP_8] = .kp_8;
    key_map[c.GLFW_KEY_KP_9] = .kp_9;
    key_map[c.GLFW_KEY_KP_DECIMAL] = .kp_decimal;
    key_map[c.GLFW_KEY_KP_DIVIDE] = .kp_divide;
    key_map[c.GLFW_KEY_KP_MULTIPLY] = .kp_multiply;
    key_map[c.GLFW_KEY_KP_SUBTRACT] = .kp_subtract;
    key_map[c.GLFW_KEY_KP_ADD] = .kp_add;
    key_map[c.GLFW_KEY_KP_ENTER] = .kp_enter;
    key_map[c.GLFW_KEY_KP_EQUAL] = .kp_equal;
    key_map[c.GLFW_KEY_LEFT_SHIFT] = .left_shift;
    key_map[c.GLFW_KEY_LEFT_CONTROL] = .left_control;
    key_map[c.GLFW_KEY_LEFT_ALT] = .left_alt;
    key_map[c.GLFW_KEY_LEFT_SUPER] = .left_super;
    key_map[c.GLFW_KEY_RIGHT_SHIFT] = .right_shift;
    key_map[c.GLFW_KEY_RIGHT_CONTROL] = .right_control;
    key_map[c.GLFW_KEY_RIGHT_ALT] = .right_alt;
    key_map[c.GLFW_KEY_RIGHT_SUPER] = .right_super;
    key_map[c.GLFW_KEY_MENU] = .menu;

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
    }
}
pub fn swapBuffers(self: *Self) !void {
    if (self.window) |window| {
        const alpha: gl.float = 1;
        gl.ClearColor(0, 0, 0, alpha);
        gl.Clear(gl.COLOR_BUFFER_BIT);
        c.glfwSwapBuffers(window);
    }
}

fn keyCallback(win: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = scancode;
    _ = mods;
    const self: *Self = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(win).?));
    switch (key) {
        c.GLFW_KEY_ESCAPE => {
            self.core.pushEvent(.requestExit);
        },
        else => {},
    }
    const state: nux.Input.State = if (action == c.GLFW_RELEASE) .released else .pressed;
    if (key_map[@intCast(key)]) |k| {
        self.core.pushEvent(.{ .keyPressed = .{
            .key = k,
            .state = state,
        } });
    }
}
