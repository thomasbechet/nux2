const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Platform = nux.Platform.GPU;

const Component = struct {
    encoder: nux.Renderer.Encoder,
    constants_buffer: nux.Renderer.Buffer,
    quads: std.ArrayList(Platform.Quad),
    quads_buffer: nux.Renderer.Buffer,
    batches: std.ArrayList(Platform.Batch),
    batches_buffer: nux.Renderer.Buffer,
    active_batch: Platform.Batch,

    pub fn init(mod: *Self) !@This() {
        return .{
            .encoder = .init(mod.renderer),
            .constants_buffer = try .init(mod.renderer, .constants, @sizeOf(Platform.Constants)),
            .quads = try .initCapacity(mod.allocator, 64),
            .quads_buffer = try .init(mod.renderer, .quads, @sizeOf(Platform.Quad) * 128),
            .batches = try .initCapacity(mod.allocator, 64),
            .batches_buffer = try .init(mod.renderer, .batches, @sizeOf(Platform.Batch) * 128),
            .active_batch = undefined,
        };
    }
    pub fn deinit(self: *Component, mod: *Self) void {
        self.quads.deinit(mod.allocator);
        self.batches.deinit(mod.allocator);
    }
};

allocator: std.mem.Allocator,
renderer: *nux.Renderer,
components: nux.Components(Component),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
