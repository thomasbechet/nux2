const std = @import("std");
const Core = @import("../core.zig").Core;
const Logger = @import("../base/Logger.zig");

const c = @cImport({
    @cInclude("wren.h");
});

const Self = @This();

allocator: std.mem.Allocator,
logger: *Logger,
vm: *c.WrenVM,

fn writeFn(vm: ?*c.WrenVM, text: [*c]const u8) callconv(.c) void {
    const self: *Self = @ptrCast(@alignCast(c.wrenGetUserData(vm)));
    self.logger.info("{s}", .{text});
}
fn errorFn(vm: ?*c.WrenVM, error_type: c.WrenErrorType, module: [*c]const u8, line: c_int, msg: [*c]const u8) callconv(.c) void {
    const self: *Self = @ptrCast(@alignCast(c.wrenGetUserData(vm)));
    switch (error_type) {
        c.WREN_ERROR_COMPILE => {
            self.logger.err("[{s} line {d}] [Error] {s}", .{ module, line, msg });
        },
        c.WREN_ERROR_STACK_TRACE => {
            self.logger.err("[{s} line {d}] in {s}", .{ module, line, msg });
        },
        c.WREN_ERROR_RUNTIME => {
            self.logger.err("[Runtime Error] {s}", .{msg});
        },
        else => {},
    }
}
fn loadModuleFn(vm: ?*c.WrenVM, name: [*c]const u8) callconv(.c) c.WrenLoadModuleResult {
    const self: *Self = @ptrCast(@alignCast(c.wrenGetUserData(vm)));
    self.logger.info("load {s}", .{name});
    return .{
        .userData = null,
        .onComplete = null,
        .source = null,
    };
}

pub fn init(self: *Self, core: *Core) !void {
    self.allocator = core.allocator;

    var config: c.WrenConfiguration = undefined;
    c.wrenInitConfiguration(&config);
    config.userData = self;
    config.writeFn = writeFn;
    config.errorFn = errorFn;
    config.loadModuleFn = loadModuleFn;

    self.vm = c.wrenNewVM(&config) orelse {
        self.logger.info("failed to create wren vm", .{});
        return;
    };

    const source = @embedFile("main.wren");
    const result = c.wrenInterpret(self.vm, "my_module", source);
    // result = c.wrenInterpret(self.vm, "my_module", source);
    switch (result) {
        c.WREN_RESULT_SUCCESS => {
            self.logger.info("success", .{});
        },
        c.WREN_RESULT_COMPILE_ERROR => {
            self.logger.info("compile error", .{});
        },
        c.WREN_RESULT_RUNTIME_ERROR => {
            self.logger.info("runtime error", .{});
        },
        else => {},
    }
}
pub fn deinit(self: *Self) void {
    c.wrenFreeVM(self.vm);
}
