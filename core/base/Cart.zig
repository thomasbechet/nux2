const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

pub const FileSystem = struct {
    const magic: [3]u8 = .{ 'n', 'u', 'x' };

    const HeaderData = extern struct {
        magic: [3]u8 = magic,
        version: u32 = 1,
    };
    const EntryData = extern struct {
        path_len: u32,
        data_len: u64,
    };
    const Entry = struct {
        offset: u64,
        length: u64,
    };

    handle: ?nux.Platform.File.Handle,
    path: []const u8,
    platform: nux.Platform.File,
    allocator: std.mem.Allocator,
    entries: std.StringHashMap(Entry),

    pub fn load(path: []const u8, allocator: std.mem.Allocator, platform: nux.Platform.File) !@This() {
        var cart: @This() = undefined;
        cart.allocator = allocator;
        cart.entries = .init(allocator);
        cart.path = try allocator.dupe(u8, path);
        cart.handle = null;
        cart.platform = platform;
        errdefer cart.deinit();
        // Open file
        cart.handle = try platform.vtable.open(platform.ptr, path, .read);
        errdefer platform.vtable.close(platform.ptr, cart.handle.?);
        // Get file stat
        const fstat = try platform.vtable.stat(platform.ptr, path);
        if (fstat.size < @sizeOf(HeaderData)) {
            return error.InvalidCartSize;
        }
        // Read header
        var buf: [@sizeOf(HeaderData)]u8 = undefined;
        try platform.vtable.read(platform.ptr, cart.handle.?, &buf);
        var reader = std.Io.Reader.fixed(&buf);
        const header = try reader.takeStruct(HeaderData, .little);
        if (!std.mem.eql(u8, &header.magic, &magic)) {
            return error.InvalidCartMagic;
        }
        if (header.version != 1) {
            return error.InvalidCartVersion;
        }
        // Read entries
        var entry_buf: [@sizeOf(EntryData)]u8 = undefined;
        var it: u64 = @sizeOf(HeaderData); // start after header
        while (it < fstat.size) {
            // Seek to entry
            try platform.vtable.seek(platform.ptr, cart.handle.?, it);
            try platform.vtable.read(platform.ptr, cart.handle.?, &entry_buf);
            // Read entry
            reader = std.Io.Reader.fixed(&entry_buf);
            const entry = try reader.takeStruct(EntryData, .little);
            // Read path
            const path_data = try allocator.alloc(u8, entry.path_len);
            errdefer allocator.free(path_data);
            try platform.vtable.read(platform.ptr, cart.handle.?, path_data);
            // Add entry
            const offset = it + @sizeOf(EntryData) + entry.path_len;
            try cart.entries.put(path_data, .{
                .offset = offset,
                .length = entry.data_len,
            });
            // Go to next entry
            it += @sizeOf(EntryData) + entry.path_len + entry.data_len;
        }
        return cart;
    }
    pub fn deinit(self: *@This()) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.entries.deinit();
        self.allocator.free(self.path);
        if (self.handle) |handle| {
            self.platform.vtable.close(self.platform.ptr, handle);
        }
    }
    pub fn read(self: *@This(), path: []const u8, allocator: std.mem.Allocator, comptime alignment: ?std.mem.Alignment) ![]u8 {
        if (self.entries.get(path)) |entry| {
            const buffer = try allocator.alignedAlloc(u8, alignment, entry.length);
            try self.platform.vtable.seek(self.platform.ptr, self.handle.?, entry.offset);
            try self.platform.vtable.read(self.platform.ptr, self.handle.?, buffer);
            return buffer;
        }
        return error.EntryNotFound;
    }
    pub fn stat(self: *@This(), path: []const u8) !nux.Platform.File.Stat {
        if (self.entries.get(path)) |entry| {
            return .{
                .size = entry.length,
            };
        }
        return error.EntryNotFound;
    }
    pub fn list(self: *const @This(), fileList: *nux.File.FileList) !void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            try fileList.add(entry.key_ptr.*);
        }
    }
};

const CartWriter = struct {
    writer: nux.File.Writer,
    path: []const u8,
};

allocator: std.mem.Allocator,
platform: nux.Platform.File,
cart_writer: ?CartWriter,
logger: *nux.Logger,
file: *nux.File,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.platform = core.platform.file;
    self.cart_writer = null;
}
pub fn deinit(self: *Self) void {
    self.closeCartWriter();
}

fn closeCartWriter(self: *Self) void {
    if (self.cart_writer) |*w| {
        self.allocator.free(w.path);
        w.writer.close();
        self.cart_writer = null;
    }
}
pub fn begin(self: *Self, path: []const u8) !void {
    self.closeCartWriter();

    // Create file
    const path_copy = try self.allocator.dupe(u8, path);
    errdefer self.allocator.free(path_copy);
    var writer = try nux.File.Writer.open(self.file, path, &.{});
    errdefer writer.close();

    // Write header
    _ = try writer.interface.writeStruct(FileSystem.HeaderData{}, .little);
    try writer.interface.flush();

    self.cart_writer = .{
        .writer = writer,
        .path = path_copy,
    };
}
pub fn write(self: *Self, path: []const u8, data: []const u8) !void {
    if (self.cart_writer) |*cart_writer| {
        // Write entry
        const w = &cart_writer.writer;
        try w.interface.writeStruct(FileSystem.EntryData{
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
pub fn writeGlob(self: *Self, glob: []const u8) !void {
    if (self.cart_writer) |cart_writer| {
        var fileList = try self.file.glob(glob, self.allocator);
        defer fileList.deinit();
        for (fileList.paths.items) |path| {
            if (std.mem.eql(u8, path, cart_writer.path)) {
                continue; // Don't write cart itself
            }
            const data = try self.file.read(path, self.allocator);
            defer self.allocator.free(data);
            try self.write(path, data);
        }
    }
}
