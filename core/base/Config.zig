const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const Key = struct {
    section: []const u8,
    key: []const u8,
};

const KeyContext = struct {
    pub fn hash(_: @This(), key: Key) u32 {
        var h = std.hash.Fnv1a_32.init();
        h.update(key.section);
        h.update(key.key);
        return h.final();
    }
    pub fn eql(_: @This(), a: Key, b: Key, _: usize) bool {
        return std.mem.eql(u8, a.section, b.section) and std.mem.eql(u8, a.key, b.key);
    }
};

const default_ini = @embedFile("../conf.ini");

fn parse(self: *Self, text: []const u8) !void {
    var current_section: []const u8 = "";
    var line_no: usize = 0;

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        line_no += 1;

        var line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        if (line[0] == '#' or line[0] == ';') continue;

        // [section]
        if (line[0] == '[' and line[line.len - 1] == ']') {
            current_section = std.mem.trim(u8, line[1 .. line.len - 1], " \t");
            continue;
        }

        // key = value
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse {
            self.logger.err("INI syntax error at line {}", .{line_no});
            return error.InvalidSyntax;
        };

        const key = std.mem.trim(u8, line[0..eq], " \t");
        const value = std.mem.trim(u8, line[eq + 1 ..], " \t");

        // Set config
        try self.config.put(.{ .section = current_section, .key = key }, value);
    }
}

file: *nux.File,
logger: *nux.Logger,
allocator: std.mem.Allocator,
config: std.ArrayHashMap(Key, []const u8, KeyContext, true),
ini_files: std.ArrayList([]const u8),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.config = .init(self.allocator);
    self.ini_files = .empty;

    // Load default configuration
    try self.parse(default_ini);
}
pub fn deinit(self: *Self) void {
    self.config.deinit();
    for (self.ini_files.items) |ini| {
        self.allocator.free(ini);
    }
    self.ini_files.deinit(self.allocator);
}
pub fn onStart(self: *Self) void {
    try self.loadINI();
}
pub fn loadINI(self: *Self) !void {
    const ini = try self.file.read("conf.ini", self.allocator);
    errdefer self.allocator.free(ini);
    try self.parse(ini);
    try self.ini_files.append(self.allocator, ini);
}
pub fn get(self: *Self, key: []const u8) ![]const u8 {
    var it = std.mem.splitScalar(u8, key, '.');
    const section = it.next() orelse return error.MissingSection;
    const k = it.next() orelse return error.MissingKey;
    if (self.config.get(.{ .section = section, .key = k })) |value| {
        return value;
    }
    return error.KeyNotFound;
}
pub fn getBool(self: *Self, key: []const u8) !bool {
    const value = try self.get(key);
    if (std.mem.eql(u8, value, "true")) {
        return true;
    } else if (std.mem.eql(u8, value, "false")) {
        return false;
    }
    return error.InvalidBoolValue;
}
pub fn getInt(self: *Self, comptime T: type, key: []const u8) !T {
    const value = try self.get(key);
    return std.fmt.parseInt(T, value, 10) catch return error.InvalidSizeValue;
}
pub fn getUint(self: *Self, comptime T: type, key: []const u8) !T {
    const value = try self.get(key);
    return std.fmt.parseUnsigned(T, value, 10) catch return error.InvalidSizeValue;
}
pub fn getFloat(self: *Self, key: []const u8) !f32 {
    const value = try self.get(key);
    return std.fmt.parseFloat(f32, value) catch return error.InvalidFloatValue;
}
