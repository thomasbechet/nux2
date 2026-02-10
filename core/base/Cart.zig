const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

const VFS = struct {
    const Node = struct {
        parent: u32,
        name: []const u8,
        next: ?u32 = null,
        data: union(enum) {
            file: struct {
                offset: u64,
                length: u64,
            },
            dir: struct {
                child: ?u32 = null,
            },
        },
    };

    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node),

    fn init(allocator: std.mem.Allocator) !@This() {
        var vfs = @This(){
            .allocator = allocator,
            .nodes = try .initCapacity(allocator, 8),
        };
        // Insert root node
        try vfs.nodes.append(allocator, .{ .parent = 0, .name = try allocator.dupe(u8, "/"), .data = .{ .dir = .{} } });
        return vfs;
    }
    fn deinit(self: *@This()) void {
        for (self.nodes.items) |node| {
            self.allocator.free(node.name);
        }
        self.nodes.deinit(self.allocator);
    }

    fn findChild(self: *const @This(), index: u32, name: []const u8) ?u32 {
        const node = self.nodes.items[index];
        std.debug.assert(node.data == .dir);
        var it = node.data.dir.child;
        while (it) |child| {
            const child_node = self.nodes.items[child];
            if (std.mem.eql(u8, child_node.name, name)) {
                return child;
            }
            it = child_node.next;
        }
        return null;
    }
    fn findIndex(self: *const @This(), path: []const u8) ?u32 {
        var it = std.mem.splitScalar(u8, path, '/');
        var index: u32 = 0;
        while (it.next()) |part| {
            if (part.len == 0) continue; // skip empty (leading / or //)
            if (std.mem.eql(u8, part, ".")) continue;
            if (std.mem.eql(u8, part, "..")) continue;
            const child = self.findChild(index, part) orelse return null;
            const child_node = self.nodes.items[child];
            const has_next = it.peek() != null;
            if (child_node.data == .file and has_next) {
                return null;
            }
            index = child;
        }
        return index;
    }

    fn addChild(self: *@This(), parent: u32, child: u32) void {
        self.nodes.items[child].next = self.nodes.items[parent].data.dir.child;
        self.nodes.items[parent].data.dir.child = child;
    }
    fn newFile(self: *@This(), parent: u32, name: []const u8, offset: u64, length: u64) !void {
        if (parent >= self.nodes.items.len) return error.invalidParent;
        const parent_node = self.nodes.items[parent];
        if (parent_node.data != .dir) return error.notADirectory;

        if (self.findChild(parent, name) != null) return error.alreadyExists;

        const name_copy = try self.allocator.dupe(u8, name);
        const new_index: u32 = @intCast(self.nodes.items.len);
        try self.nodes.append(self.allocator, .{
            .parent = parent,
            .name = name_copy,
            .next = null, // will be set by addChild
            .data = .{ .file = .{
                .offset = @intCast(offset),
                .length = @intCast(length),
            } },
        });
        self.addChild(parent, new_index);
    }
    fn newDir(self: *@This(), parent: u32, name: []const u8) !u32 {
        if (parent >= self.nodes.items.len) return error.invalidParent;

        const parent_node = self.nodes.items[parent];
        if (parent_node.data != .dir) return error.notADirectory;

        if (self.findChild(parent, name) != null) return error.alreadyExists;

        const name_copy = try self.allocator.dupe(u8, name);

        const new_index: u32 = @intCast(self.nodes.items.len);
        try self.nodes.append(self.allocator, .{
            .parent = parent,
            .name = name_copy,
            .next = null, // will be set by addChild
            .data = .{ .dir = .{ .child = null } },
        });

        self.addChild(parent, new_index);

        return new_index;
    }
};

pub const FileSystem = struct {
    const magic: [3]u8 = .{ 'n', 'u', 'x' };

    const HeaderData = extern struct {
        magic: [3]u8 = magic,
        version: u32 = 1,
    };
    const EntryData = extern struct {
        is_dir: bool,
        parent: u32,
        name_len: u32,
        data_len: u64,
    };

    vfs: VFS,
    handle: nux.Platform.File.Handle,
    path: []const u8,
    platform: nux.Platform.File,
    allocator: std.mem.Allocator,

    pub fn load(path: []const u8, allocator: std.mem.Allocator, platform: nux.Platform.File) !@This() {
        // Open file
        const handle = try platform.vtable.open(platform.ptr, path, .read);
        errdefer platform.vtable.close(platform.ptr, handle);
        // Get file stat
        const fstat = try platform.vtable.stat(platform.ptr, path);
        if (fstat.size < @sizeOf(HeaderData)) {
            return error.invalidCartSize;
        }
        // Read header
        var buf: [@sizeOf(HeaderData)]u8 = undefined;
        try platform.vtable.read(platform.ptr, handle, &buf);
        var reader = std.Io.Reader.fixed(&buf);
        const header = try reader.takeStruct(HeaderData, .little);
        if (!std.mem.eql(u8, &header.magic, &magic)) {
            return error.invalidCartMagic;
        }
        if (header.version != 1) {
            return error.invalidCartVersion;
        }
        // Allocate cart resources
        const path_copy = try allocator.dupe(u8, path);
        errdefer allocator.free(path_copy);
        var vfs = try VFS.init(allocator);
        errdefer vfs.deinit();
        // Read entries
        var entry_buf: [@sizeOf(EntryData)]u8 = undefined;
        var it: u64 = @sizeOf(HeaderData); // start after header
        while (it < fstat.size) {
            // Seek to entry
            try platform.vtable.seek(platform.ptr, handle, it);
            try platform.vtable.read(platform.ptr, handle, &entry_buf);
            // Read entry
            reader = std.Io.Reader.fixed(&entry_buf);
            const entry = try reader.takeStruct(EntryData, .little);
            // Read name
            const name_data = try allocator.alloc(u8, entry.name_len);
            defer allocator.free(name_data);
            try platform.vtable.read(platform.ptr, handle, name_data);
            // Check parent dir
            if (entry.parent > vfs.nodes.items.len) {
                return error.invalidParentIndex;
            }
            const parent = vfs.nodes.items[entry.parent];
            if (parent.data != .dir) {
                return error.parentIsNotADirectory;
            }
            // Create node in VFS
            if (entry.is_dir) {
                _ = try vfs.newDir(entry.parent, name_data);
            } else {
                const offset = it + @sizeOf(EntryData) + entry.name_len;
                try vfs.newFile(entry.parent, name_data, offset, entry.data_len);
            }
            // Go to next entry
            it += @sizeOf(EntryData) + entry.name_len + entry.data_len;
        }
        return .{
            .handle = handle,
            .path = path_copy,
            .platform = platform,
            .allocator = allocator,
            .vfs = vfs,
        };
    }
    pub fn deinit(self: *@This()) void {
        // Free carts
        self.platform.vtable.close(self.platform.ptr, self.handle);
        self.allocator.free(self.path);
        self.vfs.deinit();
    }
    pub fn read(self: *@This(), path: []const u8, allocator: std.mem.Allocator) ![]u8 {
        if (self.vfs.findIndex(path)) |index| {
            const node = self.vfs.nodes.items[index];
            if (node.data == .dir) return error.notAFile;
            const buffer = try allocator.alloc(u8, node.data.file.length);
            try self.platform.vtable.seek(self.platform.ptr, self.handle, node.data.file.offset);
            try self.platform.vtable.read(self.platform.ptr, self.handle, buffer);
            return buffer;
        }
        return error.entryNotFound;
    }
    pub fn stat(self: *@This(), path: []const u8) !nux.Platform.File.Stat {
        if (self.vfs.findIndex(path)) |index| {
            const node = self.vfs.nodes.items[index];
            switch (node.data) {
                .file => |file| {
                    return .{
                        .kind = .file,
                        .size = file.length,
                    };
                },
                .dir => {
                    return .{
                        .kind = .file,
                        .size = 0,
                    };
                },
            }
        }
        return error.entryNotFound;
    }
    pub fn list(self: *const @This(), path: []const u8, fileList: *nux.File.FileList) !void {
        std.log.info("QWDQWD {s}", .{path});
        if (self.vfs.findIndex(path)) |index| {
            std.log.info("QWDQWD {s}", .{path});
            const node = self.vfs.nodes.items[index];
            if (node.data == .dir) {
                var it = node.data.dir.child;
                while (it) |child_index| {
                    const child = self.vfs.nodes.items[child_index];
                    try fileList.add(child.name);
                    it = child.next;
                }
            }
        }
    }
};

const CartWriter = struct {
    vfs: VFS,
    writer: nux.File.NativeWriter,
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
        w.writer.close();
        w.vfs.deinit();
        self.cart_writer = null;
    }
}
pub fn begin(self: *Self, path: []const u8) !void {
    self.closeCartWriter();

    // Create file
    var writer = try nux.File.NativeWriter.open(self.file, path, &.{});
    errdefer writer.close();
    var vfs = try VFS.init(self.allocator);
    errdefer vfs.deinit();

    // Write header
    _ = try writer.interface.writeStruct(FileSystem.HeaderData{}, .little);
    try writer.interface.flush();

    self.cart_writer = .{
        .writer = writer,
        .vfs = vfs,
    };
}
pub fn write(self: *Self, path: []const u8, data: []const u8) !void {
    if (self.cart_writer) |*cart_writer| {
        const w = &cart_writer.writer;
        var parent_index: u32 = 0;
        // Create parent dir
        if (std.fs.path.dirname(path)) |parent| {
            var it = std.mem.splitScalar(u8, parent, '/');
            while (it.next()) |part| {
                if (cart_writer.vfs.findChild(parent_index, part)) |child| {
                    // Ensure child is a directory
                    if (cart_writer.vfs.nodes.items[child].data != .dir) {
                        return error.NotADirectory;
                    }
                    // Already exist
                    parent_index = child;
                } else {
                    // Missing, create the directory
                    const dir_index = try cart_writer.vfs.newDir(parent_index, part);
                    // Write entry
                    try w.interface.writeStruct(FileSystem.EntryData{
                        .is_dir = true,
                        .parent = parent_index,
                        .data_len = 0,
                        .name_len = @intCast(part.len),
                    }, .little);
                    // Write path
                    _ = try w.interface.write(part);
                    // Set as next parent
                    parent_index = dir_index;
                }
            }
        }
        // Create file
        const name = std.fs.path.basename(path);
        _ = try cart_writer.vfs.newFile(parent_index, name, 0, data.len);
        // Write entry
        try w.interface.writeStruct(FileSystem.EntryData{
            .is_dir = false,
            .parent = parent_index,
            .data_len = @intCast(data.len),
            .name_len = @intCast(name.len),
        }, .little);
        // Write path
        _ = try w.interface.write(name);
        // Write data
        _ = try w.interface.write(data);
        try w.interface.flush();
    }
}
