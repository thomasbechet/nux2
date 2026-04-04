const nux = @import("../nux.zig");
const std = @import("std");

const Self = @This();

pub const ID = usize;

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
    name: []const u8,
    type_hash: u32,
    state: State = .created,
    v_ptr: *anyopaque,
    v_module: VTable,
    v_component: ?nux.Component.VTable = null,
    functions: std.StringHashMap(nux.Function.Function),
    enums: std.StringHashMap(u64),

    pub fn destroy(self: *@This()) void {
        if (self.state == .created) {
            self.v_module.destroy(self.v_ptr, self.allocator);
            self.functions.deinit();
            self.enums.deinit();
        }
    }
    pub fn init(self: *@This(), core: *nux.Core) !void {
        std.log.info("INIT {s}", .{self.name});
        std.debug.assert(self.state == .created);
        if (self.v_component) |v_component| {
            try v_component.init(self.v_ptr);
        }
        try self.v_module.init(self.v_ptr, core);
        self.state = .initialized;
    }
    pub fn deinit(self: *@This()) void {
        std.log.info("DEINIT {s}", .{self.name});
        if (self.state == .initialized) {
            self.v_module.deinit(self.v_ptr);
            if (self.v_component) |v_component| {
                try v_component.deinit(self.v_ptr);
            }
            self.state = .created;
        }
    }
    pub fn start(self: *@This()) !void {
        std.log.info("START {s}", .{self.name});
        std.debug.assert(self.state == .initialized);
        try self.v_module.start(self.v_ptr);
        self.state = .started;
    }
    pub fn stop(self: *@This()) void {
        std.log.info("STOP {s}", .{self.name});
        if (self.state == .started) {
            try self.v_module.stop(self.v_ptr);
            self.state = .initialized;
        }
    }
};

core: *const nux.Core,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.core = core;
}

pub fn find(self: *Self, name: []const u8) ?ID {
    return self.core.names.get(name);
}
