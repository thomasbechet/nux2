const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

const GPUQuad = struct {
    pos: u32,
    tex: u32,
    size: u32,
};

const GPUBatch = struct {
    mode: u32,
    first: u32,
    count: u32,
    texture_width: u32,
    texture_height: u32,
    _pad: [3]u32,
    color: [4]f32,
};

const GPUConstants = struct {
    view: [16]f32,
    proj: [16]f32,
    screen_size: [2]u32,
    time: f32,
    _pad: [3]u32,
};

allocator: std.mem.Allocator,
gpu: *nux.GPU,
components: nux.Components(struct {
    encoder: nux.GPU.Encoder,
    constants_buffer: nux.GPU.Buffer,
    quads: std.ArrayList(GPUQuad),
    quads_buffer: nux.GPU.Buffer,
    batches: std.ArrayList(GPUBatch),
    batches_buffer: nux.GPU.Buffer,
    active_batch: GPUBatch,

    pub fn init(self: *Self) !@This() {
        return .{
            .encoder = .init(self.gpu),
            .constants_buffer = try .init(self.gpu, .uniform, @sizeOf(GPUConstants)),
            .quads = try .initCapacity(self.allocator, 64),
            .quads_buffer = try .init(self.gpu, .storage, @sizeOf(GPUQuad) * 128),
            .batches = try .initCapacity(self.allocator, 64),
            .batches_buffer = try .init(self.gpu, .storage, @sizeOf(GPUBatch) * 128),
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
