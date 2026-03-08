const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Platform = nux.Platform.GPU;

allocator: std.mem.Allocator,
gpu: *nux.GPU,
components: nux.Components(struct {
    encoder: nux.GPU.Encoder,
    constants_buffer: nux.GPU.Buffer,
    quads: std.ArrayList(Platform.Quad),
    quads_buffer: nux.GPU.Buffer,
    batches: std.ArrayList(Platform.Batch),
    batches_buffer: nux.GPU.Buffer,
    active_batch: Platform.Batch,

    pub fn init(self: *Self) !@This() {
        return .{
            .encoder = .init(self.gpu),
            .constants_buffer = try .init(self.gpu, .constants, @sizeOf(Platform.Constants)),
            .quads = try .initCapacity(self.allocator, 64),
            .quads_buffer = try .init(self.gpu, .quads, @sizeOf(Platform.Quad) * 128),
            .batches = try .initCapacity(self.allocator, 64),
            .batches_buffer = try .init(self.gpu, .batches, @sizeOf(Platform.Batch) * 128),
            .active_batch = undefined,
        };
    }
    pub fn deinit(self: *Self, component: *@This()) void {
        component.quads.deinit(self.allocator);
        component.batches.deinit(self.allocator);
    }
}),

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;
}
