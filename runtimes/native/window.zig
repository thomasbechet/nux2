const c = @cImport({
    @cInclude("glfw3.h");
});
const nux = @import("nux");

pub const Context = struct {
    running: bool = true,

    pub fn run(self: *@This(), core: *nux.Core) !void {
        if (c.glfwInit() == 0) {
            @panic("Failed to initialize GLFW");
        }
        const window = c.glfwCreateWindow(640, 480, "Hello World", null, null);
        c.glfwMakeContextCurrent(window);
        _ = c.glfwSetKeyCallback(window, keyCallback);
        c.glfwSetWindowUserPointer(window, @ptrCast(self));
        while (c.glfwWindowShouldClose(window) == 0 and self.running) {
            c.glfwPollEvents();
            try core.update();
            c.glfwSwapBuffers(window);
        }
        c.glfwDestroyWindow(window);
        c.glfwTerminate();
    }
};

fn keyCallback(win: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    _ = scancode;
    _ = action;
    _ = mods;
    const ctx: *Context = @ptrCast(c.glfwGetWindowUserPointer(win).?);
    switch (key) {
        c.GLFW_KEY_ESCAPE => {
            ctx.running = false;
        },
        else => {},
    }
}
