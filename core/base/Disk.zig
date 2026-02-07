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
        kind: nux.Platform.File.Kind,
        offset: u32,
        length: u32,
    };

    handle: nux.Platform.File.Handle,
    path: []const u8,
    entries: std.StringHashMap(Entry),

    fn init(mod: *Self, path: []const u8) !@This() {
        // Open file
        const handle = try mod.platform.vtable.open(mod.platform.ptr, path, .read);
        errdefer mod.platform.vtable.close(mod.platform.ptr, handle);
        // Get file stat
        const fstat = try mod.platform.vtable.stat(mod.platform.ptr, path);
        if (fstat.size < @sizeOf(HeaderData)) {
            return error.invalidCartSize;
        }
        // Read header
        var buf: [@sizeOf(HeaderData)]u8 = undefined;
        try mod.platform.vtable.read(mod.platform.ptr, handle, &buf);
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
        while (it < fstat.size) {
            // Seek to entry
            try mod.platform.vtable.seek(mod.platform.ptr, handle, it);
            try mod.platform.vtable.read(mod.platform.ptr, handle, &entry_buf);
            // Read entry
            reader = std.Io.Reader.fixed(&entry_buf);
            const entry = try reader.takeStruct(EntryData, .little);
            // Read path
            const path_data = try mod.allocator.alloc(u8, entry.path_len);
            try mod.platform.vtable.read(mod.platform.ptr, handle, path_data);
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
        mod.platform.vtable.close(mod.platform.ptr, self.handle);
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
            try mod.platform.vtable.seek(mod.platform.ptr, self.handle, entry.offset);
            try mod.platform.vtable.read(mod.platform.ptr, self.handle, buffer);
            return buffer;
        }
        return error.entryNotFound;
    }
    fn stat(self: *@This(), path: []const u8) !nux.Platform.File.Stat {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, path)) {
                if (entry.key_ptr.len == path.len) {
                    return .{
                        .kind = .file,
                        .size = entry.value_ptr.length,
                    };
                } else {
                    return .{
                        .kind = .dir,
                        .size = 0,
                    };
                }
            }
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
        const handle = try mod.platform.vtable.open(mod.platform.ptr, final_path, .read);
        defer mod.platform.vtable.close(mod.platform.ptr, handle);
        const fstat = try mod.platform.vtable.stat(mod.platform.ptr, path);
        const buffer = try allocator.alloc(u8, fstat.size);
        try mod.platform.vtable.read(mod.platform.ptr, handle, buffer);
        return buffer;
    }
    fn stat(self: *@This(), mod: *Self, path: []const u8) !nux.Platform.File.Stat {
        const final_path = try std.mem.concat(mod.allocator, u8, &.{ self.path, "/", path });
        defer mod.allocator.free(final_path);
        const handle = try mod.platform.vtable.open(mod.platform.ptr, final_path, .read);
        defer mod.platform.vtable.close(mod.platform.ptr, handle);
        return try mod.platform.vtable.stat(mod.platform.ptr, path);
    }
};

const FileSystemLayer = union(enum) {
    cart: Cart,
    fs: FileSystem,

    fn deinit(self: *@This(), mod: *Self) void {
        switch (self.*) {
            .cart => |*cart| cart.deinit(mod),
            .fs => |*fs| fs.deinit(mod),
        }
    }
};

const DirList = struct {
    names: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .allocator = allocator,
            .names = try .initCapacity(allocator, 8),
        };
    }
    fn deinit(self: *@This()) void {
        for (self.names.items) |name| {
            self.allocator.free(name);
        }
        self.names.deinit(self.allocator);
    }

    fn add(self: *@This(), name: []const u8) !void {
        for (self.names.items) |existing_name| {
            if (std.mem.eql(u8, name, existing_name)) {
                return;
            }
        }
        try self.names.append(self.allocator, try self.allocator.dupe(u8, name));
    }
};

pub const FileWriter = struct {
    disk: *Self,
    handle: nux.Platform.File.Handle,
    interface: std.Io.Writer,

    pub fn open(mod: *Self, path: []const u8, buffer: []u8) !@This() {
        return .{
            .disk = mod,
            .handle = try mod.platform.vtable.open(mod.platform.ptr, path, .write_truncate),
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
        self.disk.platform.vtable.close(self.disk.platform.ptr, self.handle);
    }

    fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const w: *FileWriter = @alignCast(@fieldParentPtr("interface", io_w));
        const disk = w.disk;
        const buffered = io_w.buffered();
        // Process buffered
        if (buffered.len != 0) {
            disk.platform.vtable.write(disk.platform.ptr, w.handle, buffered) catch {
                return error.WriteFailed;
            };
            io_w.end = 0;
        }
        // Process in data
        for (data[0 .. data.len - 1]) |buf| {
            if (buf.len == 0) continue;
            disk.platform.vtable.write(disk.platform.ptr, w.handle, buf) catch {
                return error.WriteFailed;
            };
        }
        // Process splat
        const pattern = data[data.len - 1];
        if (pattern.len == 0 or splat == 0) return 0;
        disk.platform.vtable.write(disk.platform.ptr, w.handle, pattern) catch {
            return error.WriteFailed;
        };
        // On success, we always process everything in `data`
        return std.Io.Writer.countSplat(data, splat);
    }
};

allocator: std.mem.Allocator,
platform: nux.Platform.File,
cart_writer: ?FileWriter,
layers: std.ArrayList(FileSystemLayer),
logger: *nux.Logger,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.platform = core.platform.file;
    self.layers = try .initCapacity(core.platform.allocator, 8);

    // Add platform filesystem by default
    const fs: FileSystem = try .init(self, ".");
    try self.layers.append(self.allocator, .{ .fs = fs });

    try self.logAll();
}
pub fn deinit(self: *Self) void {
    for (self.layers.items) |*disk| {
        disk.deinit(self);
    }
    self.layers.deinit(self.allocator);
}

pub fn mount(self: *Self, path: []const u8) !void {
    const cart: Cart = try .init(self, path);
    try self.layers.append(self.allocator, .{ .cart = cart });
}
pub fn logEntries(self: *Self) void {
    for (self.layers.items) |disk| {
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
fn logRecursive(self: *Self, path: []const u8, depth: u32) !void {
    self.logger.info("PATH: {s}", .{path});
    const fstat = try self.stat(path);
    switch (fstat.kind) {
        .dir => {
            var dirList = try self.list(path, self.allocator);
            defer dirList.deinit();
            for (dirList.names.items) |name| {
                var buf: [256]u8 = undefined;
                var writer = std.Io.Writer.fixed(&buf);
                try writer.print("{s}/{s}", .{ path, name });
                const subpath = buf[0..writer.end];
                self.logger.info("PATH : {s}", .{subpath});
                try self.logRecursive(subpath, depth + 1);
            }
        },
        else => {},
    }
}
pub fn logAll(self: *Self) !void {
    try self.logRecursive("/", 0);
}
pub fn read(self: *Self, path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Find first match
    var i = self.layers.items.len;
    while (i > 0) {
        i -= 1;
        switch (self.layers.items[i]) {
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
fn stat(self: *Self, path: []const u8) !nux.Platform.File.Stat {
    // Find first match
    var i = self.layers.items.len;
    while (i > 0) {
        i -= 1;
        switch (self.layers.items[i]) {
            .cart => |*cart| return cart.stat(path) catch {
                continue;
            },
            .fs => |*fs| return fs.stat(self, path) catch {
                continue;
            },
        }
    }
    return error.entryNotFound;
}

fn list(self: *Self, path: []const u8, allocator: std.mem.Allocator) !DirList {
    var dirList = try DirList.init(allocator);
    errdefer dirList.deinit();

    // Collect names for each layer
    for (self.layers.items) |layer| {
        switch (layer) {
            .cart => |*cart| {
                var it = cart.entries.keyIterator();
                while (it.next()) |entry_path| {
                    if (std.mem.startsWith(u8, entry_path.*, path)) {
                        try dirList.add(std.fs.path.basename(entry_path.*));
                    }
                }
            },
            .fs => {
                const handle = try self.platform.vtable.openDir(self.platform.ptr, path);
                defer self.platform.vtable.closeDir(self.platform.ptr, handle);
                var buf: [256]u8 = undefined;
                while (try self.platform.vtable.next(self.platform.ptr, handle, &buf)) |size| {
                    const name = buf[0..size];
                    try dirList.add(name);
                }
            },
        }
    }

    return dirList;
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
