const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Cart = struct {
    const magic: [3]u8 = .{ 'n', 'u', 'x' };

    const HeaderData = extern struct {
        magic: [3]u8 = magic,
        version: u32 = 1,
    };
    const EntryData = extern struct {
        typ: u32,
        path_len: u32,
        data_len: u32,
    };
    const Entry = struct {
        offset: u32,
        length: u32,
    };

    handle: nux.Platform.File.Handle,
    path: []const u8,
    entries: std.StringHashMap(Entry),

    fn init(self: *Self, path: []const u8) !@This() {
        // open file
        const handle = try self.file.vtable.open(self.file.ptr, path, .read);
        errdefer self.file.vtable.close(self.file.ptr, handle);
        // get file stat
        const stat = try self.file.vtable.stat(self.file.ptr, handle);
        if (stat.size < @sizeOf(HeaderData)) {
            return error.invalidCartSize;
        }
        // read header
        var headerBuf: [@sizeOf(HeaderData)]u8 = undefined;
        try self.file.vtable.read(self.file.ptr, handle, &headerBuf);
        var reader = std.Io.Reader.fixed(&headerBuf);
        const header = try reader.takeStruct(HeaderData, .little);
        if (!std.mem.eql(u8, &header.magic, &magic)) {
            return error.invalidCartMagic;
        }
        if (header.version != 1) {
            return error.invalidCartVersion;
        }
        // allocate cart resources
        const path_copy = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(path_copy);
        var entries: std.StringHashMap(Entry) = .init(self.allocator);
        // read entries
        var it: u32 = @sizeOf(HeaderData); // start after header
        while (it < stat.size) {
            // seek to entry
            try self.file.vtable.seek(self.file.ptr, handle, it);
            // read entry
            var entryBuf: [@sizeOf(EntryData)]u8 = undefined;
            try self.file.vtable.read(self.file.ptr, handle, &entryBuf);
            reader = std.Io.Reader.fixed(&entryBuf);
            const entry = try reader.takeStruct(EntryData, .little);
            // read path
            const path_data = try self.allocator.alloc(u8, entry.path_len);
            try self.file.vtable.read(self.file.ptr, handle, path_data);
            // insert entry
            const new_entry = try entries.getOrPut(path_data);
            if (new_entry.found_existing) {
                self.logger.err("ignore duplicated entry '{s}' from '{s}'", .{ path_data, path });
                self.allocator.free(path_data);
            } else {
                new_entry.value_ptr.* = .{
                    .length = entry.data_len,
                    .offset = it + @sizeOf(EntryData) + entry.path_len,
                };
            }
            // go to next entry
            it += @sizeOf(EntryData) + entry.path_len + entry.data_len;
        }
        return .{
            .handle = handle,
            .path = path_copy,
            .entries = entries,
        };
    }
    fn deinit(cart: *@This(), self: *Self) void {
        // free carts
        self.file.vtable.close(self.file.ptr, cart.handle);
        self.allocator.free(cart.path);
        // free entries
        var it = cart.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        cart.entries.deinit();
    }
    fn read(cart: *@This(), self: *Self, path: []const u8, allocator: std.mem.Allocator) ![]u8 {
        if (cart.entries.get(path)) |entry| {
            std.debug.assert(entry.length > 0);
            const buffer = try allocator.alloc(u8, entry.length);
            try self.file.vtable.seek(self.file.ptr, cart.handle, entry.offset);
            try self.file.vtable.read(self.file.ptr, cart.handle, buffer);
            return buffer;
        }
        return error.entryNotFound;
    }
};

const FileSystem = struct {
    path: []const u8,

    fn init(self: *Self, path: []const u8) !@This() {
        return .{
            .path = try self.allocator.dupe(u8, path),
        };
    }
    fn deinit(fs: *@This(), self: *Self) void {
        self.allocator.free(fs.path);
    }
    fn read(fs: *@This(), self: *Self, path: []const u8, allocator: std.mem.Allocator) ![]u8 {
        const final_path = try std.mem.concat(self.allocator, u8, &.{ fs.path, "/", path });
        defer self.allocator.free(final_path);
        const handle = try self.file.vtable.open(self.file.ptr, final_path, .read);
        defer self.file.vtable.close(self.file.ptr, handle);
        const stat = try self.file.vtable.stat(self.file.ptr, handle);
        const buffer = try allocator.alloc(u8, stat.size);
        try self.file.vtable.read(self.file.ptr, handle, buffer);
        return buffer;
    }
};

const Disk = union(enum) {
    cart: Cart,
    fs: FileSystem,

    fn deinit(disk: *@This(), self: *Self) void {
        switch (disk.*) {
            .cart => |*cart| cart.deinit(self),
            .fs => |*fs| fs.deinit(self),
        }
    }
};

allocator: std.mem.Allocator,
file: nux.Platform.File,
write_handle: ?nux.Platform.File.Handle,
disks: std.ArrayList(Disk),
logger: *nux.Logger,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.file = core.platform.file;
    self.disks = try .initCapacity(core.platform.allocator, 8);

    // add platform filesystem by default
    const fs: FileSystem = try .init(self, ".");
    try self.disks.append(self.allocator, .{ .fs = fs });
}
pub fn deinit(self: *Self) void {
    for (self.disks.items) |*disk| {
        disk.deinit(self);
    }
    self.disks.deinit(self.allocator);
}

pub fn mount(self: *Self, path: []const u8) !void {
    const cart: Cart = try .init(self, path);
    try self.disks.append(self.allocator, .{ .cart = cart });
}
pub fn log(self: *Self) void {
    for (self.disks.items) |disk| {
        switch (disk) {
            .cart => |cart| {
                var it = cart.entries.iterator();
                while (it.next()) |value| {
                    const entry = value.value_ptr;
                    self.logger.info("{s} length {d} offset {d}", .{ value.key_ptr.*, entry.length, entry.offset });
                }
            },
            .fs => {},
        }
    }
}
pub fn read(self: *Self, path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    for (self.disks.items) |*disk| {
        switch (disk.*) {
            .cart => |*cart| return cart.read(self, path, allocator) catch {
                continue;
            },
            .fs => |*fs| return fs.read(self, path, allocator) catch {
                continue;
            },
        }
    }
    return error.entryNotFound;
}

fn closeWriteFile(self: *Self) void {
    if (self.write_handle) |handle| {
        self.file.vtable.close(self.file.ptr, handle);
        self.write_handle = null;
    }
}
pub fn writeCart(self: *Self, path: []const u8) !void {
    // create file
    self.write_handle = try self.file.vtable.open(self.file.ptr, path, .write_truncate);
    errdefer self.closeWriteFile();
    // write header
    var buf: [@sizeOf(Cart.HeaderData)]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try writer.writeStruct(Cart.HeaderData{}, .little);
    try self.file.vtable.write(self.file.ptr, self.write_handle.?, &buf);
}
pub fn writeEntry(self: *Self, path: []const u8, data: []const u8) !void {
    if (self.write_handle) |handle| {
        // write entry
        const entry = Cart.EntryData{
            .typ = 1,
            .data_len = @intCast(data.len),
            .path_len = @intCast(path.len),
        };
        var buf: [@sizeOf(Cart.EntryData)]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buf);
        try writer.writeStruct(entry, .little);
        try self.file.vtable.write(self.file.ptr, handle, &buf);
        // write path
        try self.file.vtable.write(self.file.ptr, handle, path);
        // write data
        try self.file.vtable.write(self.file.ptr, handle, data);
    }
}
