const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const IniError = error{
    UnknownSection,
    UnknownKey,
    InvalidValue,
    UnsupportedType,
    InvalidSyntax,
};

fn loadIniIntoStruct(allocator: std.mem.Allocator, text: []const u8, config: anytype) !void {
    const T = @TypeOf(config.*);
    comptime {
        if (@typeInfo(T) != .@"struct")
            @compileError("cfg must point to a struct");
    }

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
            // std.debug.print("INI syntax error at line {}\n", .{line_no});
            return IniError.InvalidSyntax;
        };

        const key = std.mem.trim(u8, line[0..eq], " \t");
        const value = std.mem.trim(u8, line[eq + 1 ..], " \t");

        setField(allocator, config, current_section, key, value) catch |err| {
            // std.debug.print("INI error at line {}: {}\n", .{ line_no, err });
            return err;
        };
    }
}

fn setField(
    allocator: std.mem.Allocator,
    cfg: anytype,
    section: []const u8,
    key: []const u8,
    value: []const u8,
) !void {
    const T = @TypeOf(cfg.*);
    const ti = @typeInfo(T).@"struct";
    inline for (ti.fields) |f| {
        if (std.mem.eql(u8, f.name, section)) {
            const sub = &@field(cfg.*, f.name);
            return setSubField(allocator, sub, key, value);
        }
    }
    std.debug.print("Unknown section '{s}'\n", .{section});
    return IniError.UnknownSection;
}

fn setSubField(
    allocator: std.mem.Allocator,
    sub: anytype,
    key: []const u8,
    value: []const u8,
) !void {
    const ST = @TypeOf(sub.*);
    const sti = @typeInfo(ST).@"struct";
    inline for (sti.fields) |f| {
        if (std.mem.eql(u8, f.name, key)) {
            const field_ptr = &@field(sub.*, f.name);
            parseAndAssign(allocator, field_ptr, value) catch {
                std.debug.print("Invalid value for '{s}'\n", .{key});
                return IniError.InvalidValue;
            };
            return;
        }
    }
    std.debug.print("Unknown key '{s}'\n", .{key});
    return IniError.UnknownKey;
}

fn parseAndAssign(allocator: std.mem.Allocator, field_ptr: anytype, value: []const u8) !void {
    const FT = @TypeOf(field_ptr.*);

    switch (@typeInfo(FT)) {
        .bool => {
            if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")) {
                field_ptr.* = true;
            } else if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0")) {
                field_ptr.* = false;
            } else {
                return IniError.InvalidValue;
            }
        },
        .int => {
            field_ptr.* = std.fmt.parseInt(FT, value, 10) catch return IniError.InvalidValue;
        },
        .float => {
            field_ptr.* = std.fmt.parseFloat(FT, value) catch return IniError.InvalidValue;
        },
        .pointer => |p| {
            if (p.size == .Slice and p.child == u8) {
                field_ptr.* = try allocator.dupe(u8, value);
            } else {
                return IniError.UnsupportedType;
            }
        },
        else => return IniError.UnsupportedType,
    }
}

const Config = struct {
    window: struct { width: u32 = 900, height: u32 = 450 } = .{},
};

file: *nux.File,
logger: *nux.Logger,
allocator: std.mem.Allocator,
config: Config = .{},

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
    self.config = .{};
}
pub fn loadINI(self: *Self) !void {
    const ini = try self.file.read("conf.ini", self.allocator);
    defer self.allocator.free(ini);
    try loadIniIntoStruct(self.allocator, ini, &self.config);
    self.logger.info("CONF: {any}", .{self.config});
}
