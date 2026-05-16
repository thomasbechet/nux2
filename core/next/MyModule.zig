const nux = @import("../nux.zig");

pub const Register = struct {
    pub fn function(self: *Register, func: anytype) !void {}
    pub fn component(self: *Register, comp: anytype) !void {}
};

pub const MyModule = struct {


    fn myCall(self: *MyModule, id: nux.ID, value: u32) !void {

    }

    pub fn register(self: *MyModule, reg: *Register) !void {
        try reg.register(self, myCall);
    }
    pub fn 
};
