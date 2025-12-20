const std = @import("std");
const nux = @import("core.zig");

pub const Module = struct {
    pub const Error = error{
        moduleNotFound,
    };

    allocator: std.mem.Allocator,
    name: []const u8,
    v_ptr: *anyopaque,
    v_init: ?*const fn (*anyopaque, core: *nux.Core) anyerror!void,
    v_deinit: ?*const fn (*anyopaque) void,
    v_update: ?*const fn (*anyopaque) anyerror!void,
    v_destroy: *const fn (std.mem.Allocator, *anyopaque) void,

    pub fn create(comptime T: type, allocator: std.mem.Allocator) !@This() {
        const mod: *T = try allocator.create(T);

        const gen = struct {
            const PT = @typeInfo(*T).pointer.child;
            fn init(pointer: *anyopaque, c: *nux.Core) anyerror!void {
                const self: *T = @ptrCast(@alignCast(pointer));
                inline for (@typeInfo(T).@"struct".fields) |field| {
                    if (@typeInfo(field.type) == .@"struct" and @hasDecl(field.type, "IsObjects")) {}
                }
                if (@hasDecl(PT, "init")) {
                    return PT.init(self, c);
                }
            }
            fn deinit(pointer: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(PT, "deinit")) {
                    PT.deinit(self);
                }
            }
            fn update(pointer: *anyopaque) anyerror!void {
                const self: *T = @ptrCast(@alignCast(pointer));
                if (@hasDecl(PT, "update")) {
                    return PT.update(self);
                }
            }
            fn free(alloc: std.mem.Allocator, pointer: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(pointer));
                alloc.destroy(self);
            }
        };

        return .{
            .allocator = allocator,
            .name = @typeName(T),
            .v_ptr = mod,
            .v_init = gen.init,
            .v_deinit = gen.deinit,
            .v_update = gen.update,
            .v_destroy = gen.free,
        };
    }
    pub fn destroy(self: *@This()) void {
        self.v_destroy(self.allocator, self.v_ptr);
    }
    pub fn init(self: *@This(), core: *nux.Core) !void {
        if (self.v_init) |call| {
            try call(self.v_ptr, core);
        }
    }
    pub fn deinit(self: *@This()) void {
        if (self.v_deinit) |call| {
            call(self.v_ptr);
        }
    }
    pub fn update(self: *@This()) !void {
        if (self.v_update) |call| {
            try call(self.v_ptr);
        }
    }
};

modules: std.StringHashMap(Module),

pub fn init(allocator: std.mem.Allocator) !@This() {
    return .{
        .modules = .init(allocator),
    };
}
pub fn deinit(self: *@This()) void {
    var it = self.modules.iterator();
    while (it.next()) |entry| {
        std.log.info("deinit module {s}...", .{entry.key_ptr.*});
        entry.value_ptr.deinit();
    }
    it = self.modules.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.destroy();
    }
    self.modules.deinit();
    self.allocator.destroy(self);
}

pub fn update(self: *@This()) !void {
    var it = self.modules.iterator();
    while (it.next()) |entry| {
        try entry.value_ptr.update();
    }
}

fn registerModules(self: *nux.Core, comptime mods: anytype) !void {
    inline for (mods) |mod| {
        std.log.info("register module {s}...", .{@typeName(mod)});
        try self.modules.put(@typeName(mod), try .create(mod, self.allocator));
    }
    inline for (mods) |mod| {
        std.log.info("init module {s}...", .{@typeName(mod)});
        try self.modules.getPtr(@typeName(mod)).?.init(self);
    }
}

fn registerModule(self: *nux.Core, comptime T: anytype) !*T {
    try self.registerModules(.{T});
    return self.getModule(T);
}

pub fn getModule(self: *@This(), comptime T: type) !*T {
    if (self.modules.getPtr(@typeName(T))) |mod| {
        return @ptrCast(@alignCast(mod.v_ptr));
    }
    return Module.Error.moduleNotFound;
}
