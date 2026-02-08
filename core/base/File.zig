const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const NativeFileSystem = struct {
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

const Layer = union(enum) {
    cart: nux.Cart.FileSystem,
    fs: NativeFileSystem,

    fn deinit(self: *@This(), mod: *Self) void {
        switch (self.*) {
            .cart => |*cart| cart.deinit(mod.cart),
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

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.platform = core.platform.file;
    self.layers = try .initCapacity(core.platform.allocator, 8);

    // Add platform filesystem by default
    const fs: NativeFileSystem = try .init(self, ".");
    try self.layers.append(self.allocator, .{ .fs = fs });

    try self.logAll();
}
pub fn deinit(self: *Self) void {
    for (self.layers.items) |*layer| {
        layer.deinit(self);
    }
    self.layers.deinit(self.allocator);
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
                if (cart.vfs.findIndex(path)) |index| {
                    const node = cart.vfs.nodes.items[index];
                    if (node.data == .dir) {
                        var it = node.data.dir.child;
                        while (it) |child_index| {
                            const child = cart.vfs.nodes.items[child_index];
                            try dirList.add(child.name);
                            it = child.next;
                        }
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
