const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

pub const ID = struct {
    index: usize,
};
pub const State = enum(u32) {
    created,
    initialized,
    started,
};

pub const VTable = struct {
    init: *const fn (*anyopaque, core: *nux.Core) anyerror!void,
    deinit: *const fn (*anyopaque) void,
    start: *const fn (*anyopaque) anyerror!void,
    stop: *const fn (*anyopaque) void,
    destroy: *const fn (*anyopaque, std.mem.Allocator) void,
};

pub const Module = struct {
    name: [:0]const u8,
    type_hash: u32,
    state: State = .created,
    v_ptr: *anyopaque,
    v_module: VTable,
    v_component: ?nux.Component.VTable = null,
    functions: std.ArrayList(nux.Function.Type),
    enums: std.ArrayList(nux.Enum.Type),

    pub fn destroy(self: *@This(), allocator: std.mem.Allocator) void {
        if (self.state == .created) {
            self.v_module.destroy(self.v_ptr, allocator);
            self.functions.deinit(allocator);
            self.enums.deinit(allocator);
        }
    }
    pub fn init(self: *@This(), core: *nux.Core, id: nux.ModuleID) !void {
        std.debug.assert(self.state == .created);
        if (self.v_component) |v_component| {
            const node = core.getModuleByType(nux.Node) orelse unreachable;
            try v_component.init(
                self.v_ptr,
                node,
                core.platform.allocator,
                id,
            );
        }
        try self.v_module.init(self.v_ptr, core);
        self.state = .initialized;
    }
    pub fn deinit(self: *@This()) void {
        if (self.state == .initialized) {
            self.v_module.deinit(self.v_ptr);
            if (self.v_component) |v_component| {
                v_component.deinit(self.v_ptr);
            }
            self.state = .created;
        }
    }
    pub fn start(self: *@This()) !void {
        std.debug.assert(self.state == .initialized);
        try self.v_module.start(self.v_ptr);
        self.state = .started;
    }
    pub fn stop(self: *@This()) void {
        if (self.state == .started) {
            self.v_module.stop(self.v_ptr);
            self.state = .initialized;
        }
    }
};

core: *nux.Core,

pub fn find(self: *Self, name: []const u8) ?ID {
    return self.core.names.get(name);
}
pub fn count(self: *Self) u32 {
    return @intCast(self.core.modules.items.len);
}
pub fn getName(self: *Self, index: u32) ![]const u8 {
    const module = try self.core.getModuleByIndex(@intCast(index));
    return module.name;
}
