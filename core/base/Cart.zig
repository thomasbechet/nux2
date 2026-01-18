const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const CartHeader = extern struct {
    magic: [3]u8 = magic,
    version: u32 = 1,
};
const CartEntry = extern struct {
    typ: u32,
    path_len: u32,
    data_len: u32,
};

const Cart = struct {
    handle: nux.Platform.File.Handle,
    path: []const u8,
};
const Entry = struct {
    cart: u32,
    offset: u32,
    length: u32,
};

const magic: [3]u8 = .{ 'n', 'u', 'x' };

allocator: std.mem.Allocator,
file: nux.Platform.File,
write_handle: ?nux.Platform.File.Handle,
carts: std.ArrayList(Cart),
entries: std.StringHashMap(Entry),
logger: *nux.Logger,

fn closeWriteFile(self: *Self) void {
    if (self.write_handle) |handle| {
        self.file.vtable.close(self.file.ptr, handle);
        self.write_handle = null;
    }
}

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.file = core.platform.file;
    self.carts = try .initCapacity(core.platform.allocator, 8);
    self.entries = .init(core.platform.allocator);

    try self.writeCart("cart.bin");
    try self.writeEntry("myentry", &.{ 0xCA, 0xFE });
    try self.writeEntry("myentry2", &.{ 0xAA, 0xBB, 0xCC });
    try self.writeEntry("myentry3", &.{ 0xAA, 0xBB, 0xCC });
    try self.mount("cart.bin");
    self.log();
    var buf: [3]u8 = undefined;
    try self.read("myentry3", &buf);
    std.debug.assert(std.mem.eql(u8, &buf, &.{ 0xAA, 0xBB, 0xCC }));
}
pub fn deinit(self: *Self) void {
    self.closeWriteFile();
    // free carts
    for (self.carts.items) |cart| {
        self.file.vtable.close(self.file.ptr, cart.handle);
        self.allocator.free(cart.path);
    }
    self.carts.deinit(self.allocator);
    // free entries
    var it = self.entries.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key_ptr.*);
    }
    self.entries.deinit();
}

pub fn mount(self: *Self, path: []const u8) !void {
    // open file
    const handle = try self.file.vtable.open(self.file.ptr, path, .read);
    errdefer self.file.vtable.close(self.file.ptr, handle);
    // get file stat
    const stat = try self.file.vtable.stat(self.file.ptr, handle);
    if (stat.size < @sizeOf(CartHeader)) {
        return error.invalidCartSize;
    }
    // read header
    var headerBuf: [@sizeOf(CartHeader)]u8 = undefined;
    try self.file.vtable.read(self.file.ptr, handle, &headerBuf);
    var reader = std.Io.Reader.fixed(&headerBuf);
    const header = try reader.takeStruct(CartHeader, .little);
    if (!std.mem.eql(u8, &header.magic, &magic)) {
        return error.invalidCartMagic;
    }
    if (header.version != 1) {
        return error.invalidCartVersion;
    }
    // add cart entry
    const cart_index = self.carts.items.len;
    try self.carts.append(self.allocator, .{
        .handle = handle,
        .path = try self.allocator.dupe(u8, path),
    });
    // read entries
    var it: u32 = @sizeOf(CartHeader); // start after header
    while (it < stat.size) {
        // seek to entry
        try self.file.vtable.seek(self.file.ptr, handle, it);
        // read entry
        var entryBuf: [@sizeOf(CartEntry)]u8 = undefined;
        try self.file.vtable.read(self.file.ptr, handle, &entryBuf);
        reader = std.Io.Reader.fixed(&entryBuf);
        const entry = try reader.takeStruct(CartEntry, .little);
        // read path
        const path_data = try self.allocator.alloc(u8, entry.path_len);
        try self.file.vtable.read(self.file.ptr, handle, path_data);
        // insert entry
        const new_entry = try self.entries.getOrPut(path_data);
        if (new_entry.found_existing) {
            self.logger.err("ignore duplicated entry '{s}' from '{s}'", .{ path_data, path });
            self.allocator.free(path_data);
        } else {
            new_entry.value_ptr.* = .{
                .cart = @intCast(cart_index),
                .length = entry.data_len,
                .offset = it + @sizeOf(CartEntry) + entry.path_len,
            };
        }
        // go to next entry
        it += @sizeOf(CartEntry) + entry.path_len + entry.data_len;
    }
}
pub fn log(self: *Self) void {
    var it = self.entries.iterator();
    while (it.next()) |value| {
        const entry = value.value_ptr;
        self.logger.info("{s} length {d} offset {d}", .{ value.key_ptr.*, entry.length, entry.offset });
    }
}
pub fn read(self: *Self, path: []const u8, buffer: []u8) !void {
    if (self.entries.get(path)) |entry| {
        const cart = &self.carts.items[entry.cart];
        try self.file.vtable.seek(self.file.ptr, cart.handle, entry.offset);
        try self.file.vtable.read(self.file.ptr, cart.handle, buffer);
    }
}
pub fn readAlloc(self: *Self, path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (self.entries.get(path)) |entry| {
        std.debug.assert(entry.length > 0);
        const buffer = try allocator.alloc(u8, entry.length);
        const cart = &self.carts.items[entry.cart];
        try self.file.vtable.seek(self.file.ptr, cart.handle, entry.offset);
        try self.file.vtable.read(self.file.ptr, cart.handle, buffer);
        return buffer;
    }
    return error.entryNotFound;
}
pub fn writeCart(self: *Self, path: []const u8) !void {
    // create file
    self.write_handle = try self.file.vtable.open(self.file.ptr, path, .write_truncate);
    errdefer self.closeWriteFile();
    // write header
    var buf: [@sizeOf(CartHeader)]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try writer.writeStruct(CartHeader{}, .little);
    try self.file.vtable.write(self.file.ptr, self.write_handle.?, &buf);
}
pub fn writeEntry(self: *Self, path: []const u8, data: []const u8) !void {
    if (self.write_handle) |handle| {
        // write entry
        const entry = CartEntry{
            .typ = 1,
            .data_len = @intCast(data.len),
            .path_len = @intCast(path.len),
        };
        var buf: [@sizeOf(CartEntry)]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buf);
        try writer.writeStruct(entry, .little);
        try self.file.vtable.write(self.file.ptr, handle, &buf);
        // write path
        try self.file.vtable.write(self.file.ptr, handle, path);
        // write data
        try self.file.vtable.write(self.file.ptr, handle, data);
    }
}
