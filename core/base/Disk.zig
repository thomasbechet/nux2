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

    fn init(mod: *Self, path: []const u8) !@This() {
        // Open file
        const handle = try mod.platform_file.vtable.open(mod.platform_file.ptr, path, .read);
        errdefer mod.platform_file.vtable.close(mod.platform_file.ptr, handle);
        // Get file stat
        const stat = try mod.platform_file.vtable.stat(mod.platform_file.ptr, handle);
        if (stat.size < @sizeOf(HeaderData)) {
            return error.invalidCartSize;
        }
        // Read header
        var buf: [@sizeOf(HeaderData)]u8 = undefined;
        try mod.platform_file.vtable.read(mod.platform_file.ptr, handle, &buf);
        var reader = std.Io.Reader.fixed(&buf);
        const header = try reader.takeStruct(HeaderData, .little);
        if (!std.mem.eql(u8, &header.magic, &magic)) {
            return error.invalidCartMagic;
        }
        if (header.version != 1) {
            return error.invalidCartVersion;
        }
        // Allocate cart resources
        const path_copy = try mod.allocator.dupe(u8, path);
        errdefer mod.allocator.free(path_copy);
        var entries: std.StringHashMap(Entry) = .init(mod.allocator);
        // Read entries
        var entry_buf: [@sizeOf(EntryData)]u8 = undefined;
        var it: u32 = @sizeOf(HeaderData); // start after header
        while (it < stat.size) {
            // Seek to entry
            try mod.platform_file.vtable.seek(mod.platform_file.ptr, handle, it);
            try mod.platform_file.vtable.read(mod.platform_file.ptr, handle, &entry_buf);
            // Read entry
            reader = std.Io.Reader.fixed(&entry_buf);
            const entry = try reader.takeStruct(EntryData, .little);
            // Read path
            const path_data = try mod.allocator.alloc(u8, entry.path_len);
            try mod.platform_file.vtable.read(mod.platform_file.ptr, handle, path_data);
            // Insert entry
            const new_entry = try entries.getOrPut(path_data);
            if (new_entry.found_existing) {
                mod.logger.err("ignore duplicated entry '{s}' from '{s}'", .{ path_data, path });
                mod.allocator.free(path_data);
            } else {
                new_entry.value_ptr.* = .{
                    .length = entry.data_len,
                    .offset = it + @sizeOf(EntryData) + entry.path_len,
                };
            }
            // Go to next entry
            it += @sizeOf(EntryData) + entry.path_len + entry.data_len;
        }
        return .{
            .handle = handle,
            .path = path_copy,
            .entries = entries,
        };
    }
    fn deinit(self: *@This(), mod: *Self) void {
        // Free carts
        mod.platform_file.vtable.close(mod.platform_file.ptr, self.handle);
        mod.allocator.free(self.path);
        // Free entries
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            mod.allocator.free(entry.key_ptr.*);
        }
        self.entries.deinit();
    }
    fn read(self: *@This(), mod: *Self, path: []const u8, allocator: std.mem.Allocator) ![]u8 {
        if (self.entries.get(path)) |entry| {
            const buffer = try allocator.alloc(u8, entry.length);
            try mod.platform_file.vtable.seek(mod.platform_file.ptr, self.handle, entry.offset);
            try mod.platform_file.vtable.read(mod.platform_file.ptr, self.handle, buffer);
            return buffer;
        }
        return error.entryNotFound;
    }
};

const FileSystem = struct {
    path: []const u8,

    fn init(mod: *Self, path: []const u8) !@This() {
        return .{
            .path = try mod.allocator.dupe(u8, path),
        };
    }
    fn deinit(self: *@This(), mod: *Self) void {
        mod.allocator.free(self.path);
    }
    fn read(self: *@This(), mod: *Self, path: []const u8, allocator: std.mem.Allocator) ![]u8 {
        const final_path = try std.mem.concat(mod.allocator, u8, &.{ self.path, "/", path });
        defer mod.allocator.free(final_path);
        const handle = try mod.platform_file.vtable.open(mod.platform_file.ptr, final_path, .read);
        defer mod.platform_file.vtable.close(mod.platform_file.ptr, handle);
        const stat = try mod.platform_file.vtable.stat(mod.platform_file.ptr, handle);
        const buffer = try allocator.alloc(u8, stat.size);
        try mod.platform_file.vtable.read(mod.platform_file.ptr, handle, buffer);
        return buffer;
    }
};

const Disk = union(enum) {
    cart: Cart,
    fs: FileSystem,

    fn deinit(self: *@This(), mod: *Self) void {
        switch (self.*) {
            .cart => |*cart| cart.deinit(mod),
            .fs => |*fs| fs.deinit(mod),
        }
    }
};

pub const FileWriter = struct {
    disk: *Self,
    handle: nux.Platform.File.Handle,
    interface: std.Io.Writer,

    pub fn open(mod: *Self, path: []const u8, buffer: []u8) !@This() {
        return .{
            .disk = mod,
            .handle = try mod.platform_file.vtable.open(mod.platform_file.ptr, path, .write_truncate),
            .interface = .{
                .vtable = &.{
                    .drain = drain,
                },
                .buffer = buffer,
            },
        };
    }
    pub fn close(self: *@This()) void {
        self.interface.flush() catch {};
        self.disk.platform_file.vtable.close(self.disk.platform_file.ptr, self.handle);
    }

    fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const w: *FileWriter = @alignCast(@fieldParentPtr("interface", io_w));
        const disk = w.disk;
        const buffered = io_w.buffered();
        // Process buffered
        if (buffered.len != 0) {
            disk.platform_file.vtable.write(disk.platform_file.ptr, w.handle, buffered) catch {
                return error.WriteFailed;
            };
            io_w.end = 0;
        }
        // Process in data
        for (data[0 .. data.len - 1]) |buf| {
            if (buf.len == 0) continue;
            disk.platform_file.vtable.write(disk.platform_file.ptr, w.handle, buf) catch {
                return error.WriteFailed;
            };
        }
        // Process splat
        const pattern = data[data.len - 1];
        if (pattern.len == 0 or splat == 0) return 0;
        disk.platform_file.vtable.write(disk.platform_file.ptr, w.handle, pattern) catch {
            return error.WriteFailed;
        };
        // On success, we always process everything in `data`
        return std.Io.Writer.countSplat(data, splat);
    }
};

allocator: std.mem.Allocator,
platform_file: nux.Platform.File,
platform_dir: nux.Platform.Dir,
cart_writer: ?FileWriter,
disks: std.ArrayList(Disk),
logger: *nux.Logger,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.platform_file = core.platform.file;
    self.platform_dir = core.platform.dir;
    self.disks = try .initCapacity(core.platform.allocator, 8);

    // Add platform filesystem by default
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
pub fn logEntries(self: *Self) void {
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
    // Create file
    self.cart_writer = try .open(self, path, &.{});
    errdefer self.closeCartWriter();
    // Write header
    const w = &self.cart_writer.?;
    _ = try w.interface.writeStruct(Cart.HeaderData{}, .little);
    try w.interface.flush();
}
pub fn writeEntry(self: *Self, path: []const u8, data: []const u8) !void {
    if (self.cart_writer) |*w| {
        // Write entry
        try w.interface.writeStruct(Cart.EntryData{
            .typ = 1,
            .data_len = @intCast(data.len),
            .path_len = @intCast(path.len),
        }, .little);
        // Write path
        _ = try w.interface.write(path);
        // Write data
        _ = try w.interface.write(data);
        try w.interface.flush();
    }
}
pub fn listFiles(self: *Self) !void {
    const handle = try self.platform_dir.vtable.open(self.platform_dir.ptr, ".");
    defer self.platform_dir.vtable.close(self.platform_dir.ptr, handle);
    while (try self.platform_dir.vtable.next(self.platform_dir.ptr, handle)) |entry| {
        switch (entry.kind) {
            .file => {
                self.logger.info("FILE {s}", .{entry.name});
            },
            .dir => {
                self.logger.info("DIR {s}", .{entry.name});
            },
            else => {},
        }
    }
}
pub fn isFile(self: *Self, path: []const u8) bool {}
pub fn isDir(self: *Self, path: []const u8) bool {}
