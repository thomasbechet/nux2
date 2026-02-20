obj: *anyopaque,
callback: *const fn (*anyopaque) anyerror!void,

pub fn call(self: @This()) anyerror!void {
    return self.callback(self.obj);
}

pub fn wrap(
    comptime T: type,
    comptime method: anytype,
    obj: *T,
) @This() {
    const Wrapper = struct {
        fn inner(ctx: *anyopaque) anyerror!void {
            const self: *T = @ptrCast(@alignCast(ctx));
            return method(self);
        }
    };

    return @This(){
        .obj = obj,
        .callback = Wrapper.inner,
    };
}
