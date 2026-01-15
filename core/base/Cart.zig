const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const CartHeader = packed struct {};

file: nux.Platform.File,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.file = core.platform.file;

    const handle = try self.file.vtable.open(self.file.ptr, "myfile.txt", .write_only);
    defer self.file.vtable.close(self.file.ptr, handle);
    try self.file.vtable.write(self.file.ptr, handle, &.{ 1, 2, 3, 4});
}
pub fn deinit(_: *Self) void {}

// pub fn read(_: *Self, _: std.mem.Allocator, _: []const u8) ![]const u8 {}
