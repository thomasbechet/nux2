const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const NativeFileSystem = struct {
    path: []const u8,
    allocator: std.mem.Allocator,
    platform: nux.Platform.File,

    fn init(path: []const u8, allocator: std.mem.Allocator, platform: nux.Platform.File) !@This() {
        return .{
            .path = try allocator.dupe(u8, path),
            .allocator = allocator,
            .platform = platform,
        };
    }
    fn deinit(self: *@This()) void {
        self.allocator.free(self.path);
    }
    fn compuleFinalPath(self: *const @This(), path: []const u8, buf: []u8) ![]const u8 {
        var w = std.Io.Writer.fixed(buf);
        try w.print("{s}/{s}", .{ self.path, path });
        return buf[0..w.end];
    }
    fn read(self: *@This(), path: []const u8, allocator: std.mem.Allocator) ![]u8 {
        var buf: [256]u8 = undefined;
        const final_path = try self.compuleFinalPath(path, &buf);
        const handle = try self.platform.vtable.open(self.platform.ptr, final_path, .read);
        defer self.platform.vtable.close(self.platform.ptr, handle);
        const fstat = try self.platform.vtable.stat(self.platform.ptr, final_path);
        const buffer = try allocator.alloc(u8, fstat.size);
        try self.platform.vtable.read(self.platform.ptr, handle, buffer);
        return buffer;
    }
    fn stat(self: *@This(), path: []const u8) !nux.Platform.File.Stat {
        var buf: [256]u8 = undefined;
        const final_path = try self.compuleFinalPath(path, &buf);
        return try self.platform.vtable.stat(self.platform.ptr, final_path);
    }
    fn list(self: *const @This(), path: []const u8, dirList: *nux.File.DirList) !void {
        var buf: [256]u8 = undefined;
        const final_path = try self.compuleFinalPath(path, &buf);
        const handle = self.platform.vtable.openDir(self.platform.ptr, final_path) catch return; // The dir might not exist
        defer self.platform.vtable.closeDir(self.platform.ptr, handle);
        while (try self.platform.vtable.next(self.platform.ptr, handle, &buf)) |size| {
            const name = buf[0..size];
            try dirList.add(name);
        }
    }
};

const Layer = union(enum) {
    cart: nux.Cart.FileSystem,
    native: NativeFileSystem,

    fn deinit(self: *@This()) void {
        switch (self.*) {
            .cart => |*cart| cart.deinit(),
            .native => |*native| native.deinit(),
        }
    }
};

pub const DirList = struct {
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

    pub fn add(self: *@This(), name: []const u8) !void {
        for (self.names.items) |existing_name| {
            if (std.mem.eql(u8, name, existing_name)) {
                return;
            }
        }
        try self.names.append(self.allocator, try self.allocator.dupe(u8, name));
    }
};

pub const NativeWriter = struct {
    file: *Self,
    handle: nux.Platform.File.Handle,
    interface: std.Io.Writer,

    pub fn open(mod: *Self, path: []const u8, buffer: []u8) !@This() {
        return .{
            .file = mod,
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
        self.file.platform.vtable.close(self.file.platform.ptr, self.handle);
    }

    fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const w: *NativeWriter = @alignCast(@fieldParentPtr("interface", io_w));
        const file = w.file;
        const buffered = io_w.buffered();
        // Process buffered
        if (buffered.len != 0) {
            file.platform.vtable.write(file.platform.ptr, w.handle, buffered) catch {
                return error.WriteFailed;
            };
            io_w.end = 0;
        }
        // Process in data
        for (data[0 .. data.len - 1]) |buf| {
            if (buf.len == 0) continue;
            file.platform.vtable.write(file.platform.ptr, w.handle, buf) catch {
                return error.WriteFailed;
            };
        }
        // Process splat
        const pattern = data[data.len - 1];
        if (pattern.len == 0 or splat == 0) return 0;
        file.platform.vtable.write(file.platform.ptr, w.handle, pattern) catch {
            return error.WriteFailed;
        };
        // On success, we always process everything in `data`
        return std.Io.Writer.countSplat(data, splat);
    }
};

allocator: std.mem.Allocator,
platform: nux.Platform.File,
layers: std.ArrayList(Layer),
logger: *nux.Logger,
cart: *nux.Cart,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.platform = core.platform.file;
    self.layers = try .initCapacity(core.platform.allocator, 8);
}
pub fn deinit(self: *Self) void {
    for (self.layers.items) |*layer| {
        layer.deinit();
    }
    self.layers.deinit(self.allocator);
}

pub fn mount(self: *Self, path: []const u8) !void {
    if (std.mem.endsWith(u8, path, ".bin")) {
        const fs: nux.Cart.FileSystem = try .load(path, self.allocator, self.platform);
        try self.layers.append(self.allocator, .{ .cart = fs });
    } else {
        const fs: NativeFileSystem = try .init(path, self.allocator, self.platform);
        try self.layers.append(self.allocator, .{ .native = fs });
    }
}
fn logRecursive(self: *Self, path: []const u8, depth: u32) !void {
    std.log.info("{s}", .{path});
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
                try self.logRecursive(subpath, depth + 1);
            }
        },
        else => {},
    }
}
pub fn logAll(self: *Self) !void {
    try self.logRecursive(".", 0);
}
pub fn read(self: *Self, path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Find first match
    var i = self.layers.items.len;
    while (i > 0) {
        i -= 1;
        switch (self.layers.items[i]) {
            .cart => |*cart| return cart.read(path, allocator) catch {
                continue;
            },
            .native => |*fs| return fs.read(path, allocator) catch {
                continue;
            },
        }
    }
    return error.entryNotFound;
}
pub fn stat(self: *Self, path: []const u8) !nux.Platform.File.Stat {
    // Find first match
    var i = self.layers.items.len;
    while (i > 0) {
        i -= 1;
        switch (self.layers.items[i]) {
            .cart => |*cart| return cart.stat(path) catch {
                continue;
            },
            .native => |*fs| return fs.stat(path) catch {
                continue;
            },
        }
    }
    return error.entryNotFound;
}
pub fn list(self: *Self, path: []const u8, allocator: std.mem.Allocator) !DirList {
    var dirList = try DirList.init(allocator);
    errdefer dirList.deinit();

    // Collect names for each layer
    for (self.layers.items) |layer| {
        switch (layer) {
            .cart => |*cart| {
                try cart.list(path, &dirList);
            },
            .native => |*native| {
                try native.list(path, &dirList);
            },
        }
    }

    return dirList;
}
pub fn logList(self: *Self, path: []const u8) !void {
    var dirList = try self.list(path, self.allocator);
    defer dirList.deinit();
    for (dirList.names.items) |name| {
        self.logger.info("- {s}", .{name});
    }
}
