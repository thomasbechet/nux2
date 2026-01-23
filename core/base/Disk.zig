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
        const handle = try self.platform.vtable.open(self.platform.ptr, path, .read);
        errdefer self.platform.vtable.close(self.platform.ptr, handle);
        var buf: [256]u8 = undefined;
        var r = self.reader(handle, &buf);
        // get file stat
        const stat = try self.platform.vtable.stat(self.platform.ptr, handle);
        if (stat.size < @sizeOf(HeaderData)) {
            return error.invalidCartSize;
        }
        // read header
        const header = try r.interface.takeStruct(HeaderData, .little);
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
            try self.platform.vtable.seek(self.platform.ptr, handle, it);
            r = self.reader(handle, &buf); // reset reader to update logical seek
            // read entry
            const entry = try r.interface.takeStruct(EntryData, .little);
            // read path
            const path_data = try r.interface.readAlloc(self.allocator, entry.path_len);
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
        self.platform.vtable.close(self.platform.ptr, cart.handle);
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
            try self.platform.vtable.seek(self.platform.ptr, cart.handle, entry.offset);
            try self.platform.vtable.read(self.platform.ptr, cart.handle, buffer);
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
        const handle = try self.platform.vtable.open(self.platform.ptr, final_path, .read);
        defer self.platform.vtable.close(self.platform.ptr, handle);
        const stat = try self.platform.vtable.stat(self.platform.ptr, handle);
        const buffer = try allocator.alloc(u8, stat.size);
        try self.platform.vtable.read(self.platform.ptr, handle, buffer);
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

const Reader = struct {
    self: *Self,
    handle: nux.Platform.File.Handle,
    interface: std.Io.Reader,

    fn stream(io_reader: *std.Io.Reader, w: *std.Io.Writer, limit: std.Io.Limit) std.Io.Reader.StreamError!usize {
        const r: *Reader = @alignCast(@fieldParentPtr("interface", io_reader));
        const self = r.self;
        const dest = limit.slice(try w.writableSliceGreedy(1));
        self.platform.vtable.read(self.platform.ptr, r.handle, dest) catch {
            return error.ReadFailed;
        };
        w.advance(dest.len);
        return dest.len;
    }

    fn init(self: *Self, handle: nux.Platform.File.Handle, buffer: []u8) Reader {
        return .{
            .self = self,
            .handle = handle,
            .interface = .{
                .vtable = &.{
                    .stream = stream,
                },
                .buffer = buffer,
                .seek = 0,
                .end = 0,
            },
        };
    }
};

pub const FileWriter = struct {
    disk: *Self,
    handle: nux.Platform.File.Handle,
    interface: std.Io.Writer,

    pub fn open(self: *Self, path: []const u8, buffer: []u8) !@This() {
        return .{
            .disk = self,
            .handle = try self.platform.vtable.open(self.platform.ptr, path, .write_truncate),
            .interface = .{
                .vtable = &.{
                    .drain = drain,
                },
                .buffer = buffer,
            },
        };
    }
    pub fn close(w: *@This()) void {
        w.interface.flush() catch {};
        w.disk.platform.vtable.close(w.disk.platform.ptr, w.handle);
    }

    fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const w: *FileWriter = @alignCast(@fieldParentPtr("interface", io_w));
        const disk = w.disk;
        const buffered = io_w.buffered();
        if (buffered.len != 0) {
            disk.platform.vtable.write(disk.platform.ptr, w.handle, buffered) catch {
                return error.WriteFailed;
            };
            return io_w.consume(buffered.len);
        }
        for (data[0 .. data.len - 1]) |buf| {
            if (buf.len == 0) continue;
            disk.platform.vtable.write(disk.platform.ptr, w.handle, buf) catch {
                return error.WriteFailed;
            };
            return io_w.consume(buf.len);
        }
        const pattern = data[data.len - 1];
        if (pattern.len == 0 or splat == 0) return 0;
        disk.platform.vtable.write(disk.platform.ptr, w.handle, pattern) catch {
            return error.WriteFailed;
        };
        return io_w.consume(pattern.len);
    }
};

fn reader(self: *Self, handle: nux.Platform.File.Handle, buffer: []u8) Reader {
    return .init(self, handle, buffer);
}

allocator: std.mem.Allocator,
platform: nux.Platform.File,
cart_writer: ?FileWriter,
disks: std.ArrayList(Disk),
logger: *nux.Logger,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.platform = core.platform.file;
    self.disks = try .initCapacity(core.platform.allocator, 8);

    // add platform filesystem by default
    const fs: FileSystem = try .init(self, ".");
    try self.disks.append(self.allocator, .{ .fs = fs });

    try self.writeCart("mycart.bin");
    try self.writeEntry("myentry1", "myentry1");
    try self.writeEntry("myentry2", "myentry2");
    try self.mount("mycart.bin");
    self.log();
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
pub fn readEntry(self: *Self, path: []const u8, allocator: std.mem.Allocator) ![]u8 {
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
fn closeCartWriter(self: *Self) void {
    if (self.cart_writer) |*w| {
        w.close();
        self.cart_writer = null;
    }
}
pub fn writeCart(self: *Self, path: []const u8) !void {
    // create file
    self.cart_writer = try .open(self, path, &.{});
    errdefer self.closeCartWriter();
    // write header
    const w = &self.cart_writer.?;
    _ = try w.interface.writeStruct(Cart.HeaderData{}, .little);
    try w.interface.flush();
}
pub fn writeEntry(self: *Self, path: []const u8, data: []const u8) !void {
    if (self.cart_writer) |*w| {
        // write entry
        try w.interface.writeStruct(Cart.EntryData{
            .typ = 1,
            .data_len = @intCast(data.len),
            .path_len = @intCast(path.len),
        }, .little);
        // write path
        _ = try w.interface.write(path);
        // write data
        _ = try w.interface.write(data);
        try w.interface.flush();
    }
}
