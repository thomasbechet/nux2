const std = @import("std");
const nux = @import("nux");
const window = @import("window.zig");
const api = @import("api.zig");

const Self = @This();

const transform = nux.transform;

pub fn main() !void {
    var context = window.Context{};
    try context.init();
}
