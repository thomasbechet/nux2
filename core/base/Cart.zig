const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const CartHeader = extern struct {
    magic: [3]u8 = .{ 'n', 'u', 'x' },
    version: u32 = 1,
    entry_count: u32,
};

const CartEntry = extern struct {
    typ: u32,
    path_len: u32,
    data_len: u32,
    next: u32,
};

file: nux.Platform.File,
active_handle: ?nux.Platform.File.Handle,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.file = core.platform.file;

    const header = CartHeader{
        .entry_count = 32,
    };

    self.active_handle = try self.file.vtable.open(self.file.ptr, "cart.bin", .write_truncate);
    errdefer self.file.vtable.close(self.file.ptr, self.active_handle.?);

    // write header
    var buf: [@sizeOf(CartEntry)]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try writer.writeStruct(header, .little);
    try self.file.vtable.write(self.file.ptr, self.active_handle.?, &buf);

    // write entry
    try self.writeEntry("MyEntry", &.{ 0, 1, 2, 3, 4 });
}
pub fn deinit(self: *Self) void {
    if (self.active_handle) |handle| {
        self.file.vtable.close(self.file.ptr, handle);
    }
}

pub fn writeEntry(self: *Self, name: []const u8, data: []const u8) !void {
    if (self.active_handle) |handle| {
        // write entry
        const entry = CartEntry{
            .typ = 1,
            .data_len = @intCast(data.len),
            .path_len = @intCast(name.len),
            .next = 0,
        };
        var buf: [@sizeOf(CartEntry)]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buf);
        try writer.writeStruct(entry, .little);
        try self.file.vtable.write(self.file.ptr, handle, &buf);
        // write path
        try self.file.vtable.write(self.file.ptr, handle, name);
        // write data
        try self.file.vtable.write(self.file.ptr, handle, data);
    }
}
