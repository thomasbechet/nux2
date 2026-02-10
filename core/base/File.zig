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
    fn compuleNativePath(self: *const @This(), path: []const u8, buf: []u8) ![]const u8 {
        var w = std.Io.Writer.fixed(buf);
        try w.print("{s}/{s}", .{ self.path, path });
        return buf[0..w.end];
    }
    fn read(self: *@This(), path: []const u8, allocator: std.mem.Allocator) ![]u8 {
        var buf: [256]u8 = undefined;
        const final_path = try self.compuleNativePath(path, &buf);
        const handle = try self.platform.vtable.open(self.platform.ptr, final_path, .read);
        defer self.platform.vtable.close(self.platform.ptr, handle);
        const fstat = try self.platform.vtable.stat(self.platform.ptr, final_path);
        const buffer = try allocator.alloc(u8, fstat.size);
        try self.platform.vtable.read(self.platform.ptr, handle, buffer);
        return buffer;
    }
    fn stat(self: *@This(), path: []const u8) !nux.Platform.File.Stat {
        var buf: [256]u8 = undefined;
        const final_path = try self.compuleNativePath(path, &buf);
        return try self.platform.vtable.stat(self.platform.ptr, final_path);
    }
    fn list(self: *const @This(), fileList: *nux.File.FileList) !void {
        var buf: [256]u8 = undefined;
        const final_path = try self.compuleNativePath(".", &buf);
        const handle = try self.platform.vtable.openDir(self.platform.ptr, final_path);
        defer self.platform.vtable.closeDir(self.platform.ptr, handle);
        while (try self.platform.vtable.next(self.platform.ptr, handle, &buf)) |size| {
            const name = buf[0..size];
            try fileList.add(name);
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

pub const FileList = struct {
    allocator: std.mem.Allocator,
    paths: std.ArrayList([]const u8),
    glob: []const u8,

    fn init(allocator: std.mem.Allocator, pattern: []const u8) !@This() {
        return .{
            .allocator = allocator,
            .paths = try .initCapacity(allocator, 8),
            .glob = pattern,
        };
    }
    pub fn deinit(self: *@This()) void {
        for (self.paths.items) |path| {
            self.allocator.free(path);
        }
        self.paths.deinit(self.allocator);
    }

    fn match(pattern: []const u8, path: []const u8) bool {
        var pattern_i: usize = 0;
        var name_i: usize = 0;
        var next_pattern_i: usize = 0;
        var next_name_i: usize = 0;
        while (pattern_i < pattern.len or name_i < path.len) {
            if (pattern_i < pattern.len) {
                const c = pattern[pattern_i];
                switch (c) {
                    '?' => { // single-character wildcard
                        if (name_i < path.len) {
                            pattern_i += 1;
                            name_i += 1;
                            continue;
                        }
                    },
                    '*' => { // zero-or-more-character wildcard
                        // Try to match at name_i.
                        // If that doesn't work out,
                        // restart at name_i+1 next.
                        next_pattern_i = pattern_i;
                        next_name_i = name_i + 1;
                        pattern_i += 1;
                        continue;
                    },
                    else => { // ordinary character
                        if (name_i < path.len and path[name_i] == c) {
                            pattern_i += 1;
                            name_i += 1;
                            continue;
                        }
                    },
                }
            }
            // Mismatch. Maybe restart.
            if (next_name_i > 0 and next_name_i <= path.len) {
                pattern_i = next_pattern_i;
                name_i = next_name_i;
                continue;
            }
            return false;
        }
        // Matched all of pattern to all of name. Success.
        return true;
    }

    pub fn add(self: *@This(), path: []const u8) !void {
        if (!match(self.glob, path)) {
            return;
        }
        for (self.paths.items) |existing_path| {
            if (std.mem.eql(u8, path, existing_path)) {
                return;
            }
        }
        try self.paths.append(self.allocator, try self.allocator.dupe(u8, path));
    }
};

pub const Writer = struct {
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
        const w: *Writer = @alignCast(@fieldParentPtr("interface", io_w));
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
pub fn glob(self: *Self, pattern: []const u8, allocator: std.mem.Allocator) !FileList {
    var fileList = try FileList.init(allocator, pattern);
    errdefer fileList.deinit();

    // Collect files for each layer
    for (self.layers.items) |layer| {
        switch (layer) {
            .cart => |*cart| {
                cart.list(&fileList) catch {};
            },
            .native => |*native| {
                native.list(&fileList) catch {};
            },
        }
    }

    return fileList;
}
pub fn logGlob(self: *Self, pattern: []const u8) !void {
    var ls = try self.glob(pattern, self.allocator);
    defer ls.deinit();
    for (ls.paths.items) |path| {
        self.logger.info("- {s}", .{path});
    }
}
