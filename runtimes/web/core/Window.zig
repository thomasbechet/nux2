const nux = @import("nux");

extern fn window_open(w: u32, h: u32) void;
extern fn window_close() void;
extern fn window_resize(w: u32, h: u32) void;

pub fn open(_: *anyopaque, w: u32, h: u32) !void {
    window_open(w, h);
}
pub fn close(_: *anyopaque) void {
    window_close();
}
pub fn resize(_: *anyopaque, w: u32, h: u32) void {
    window_resize(w, h);
}
