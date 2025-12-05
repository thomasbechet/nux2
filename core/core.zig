const std = @import("std");
pub const Objects = @import("object.zig").Objects;

pub const Modules = struct {
    transform: @import("transform.zig"),
};

pub const Core = struct {
    allocator: std.mem.Allocator = undefined,
    objects: @import("object.zig"),
    modules: Modules,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        var core: @This() = undefined;
        core.allocator = allocator;
        core.objects = try .init(allocator);
        // Initialize modules
        core.modules = .{
            .transform = try .init(&core),
        };
        return core;
    }
    pub fn deinit(core: *@This()) void {
        _ = core;
    }
};
