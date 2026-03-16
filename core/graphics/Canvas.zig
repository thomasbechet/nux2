const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Platform = nux.Platform.GPU;

const Component = struct {
    encoder: nux.GPU.Encoder,
    constants_buffer: nux.GPU.Buffer,
    quads: std.ArrayList(Platform.Quad),
    quads_buffer: nux.GPU.Buffer,
    batches: std.ArrayList(Platform.Batch),
    batches_buffer: nux.GPU.Buffer,
    active_batch: Platform.Batch,

    pub fn init(mod: *Self) !@This() {
        return .{
            .encoder = .init(mod.gpu),
            .constants_buffer = try .init(mod.gpu, .constants, @sizeOf(Platform.Constants)),
            .quads = try .initCapacity(mod.allocator, 64),
            .quads_buffer = try .init(mod.gpu, .quads, @sizeOf(Platform.Quad) * 128),
            .batches = try .initCapacity(mod.allocator, 64),
            .batches_buffer = try .init(mod.gpu, .batches, @sizeOf(Platform.Batch) * 128),
            .active_batch = undefined,
        };
    }
    pub fn deinit(self: *Component, mod: *Self) void {
        self.quads.deinit(mod.allocator);
        self.batches.deinit(mod.allocator);
    }
};

allocator: std.mem.Allocator,
gpu: *nux.GPU,
components: nux.Components(Component),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
