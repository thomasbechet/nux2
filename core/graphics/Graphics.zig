const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const GPU = nux.GPU;
const Platform = nux.Platform.GPU;

gpu: *nux.GPU,
mesh: *nux.Mesh,
texture: *nux.Texture,
material: *nux.Material,
staticmesh: *nux.StaticMesh,
transform: *nux.Transform,

allocator: std.mem.Allocator,
pipelines: struct {
    uber_opaque: GPU.Pipeline,
    uber_line: GPU.Pipeline,
    canvas: GPU.Pipeline,
    blit: GPU.Pipeline,
},
buffers: struct {
    constants: GPU.Buffer,
    batches: GPU.Buffer,
    transforms: GPU.Buffer,
},

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;

    // Create pipelines
    self.pipelines.uber_opaque = try .init(self.gpu, .{
        .type = .uber,
        .primitive = .triangles,
        .blend = false,
        .depth_test = true,
    });
    errdefer self.pipelines.uber_opaque.deinit();
    self.pipelines.uber_line = try .init(self.gpu, .{
        .type = .uber,
        .primitive = .lines,
        .blend = false,
        .depth_test = true,
    });
    errdefer self.pipelines.uber_line.deinit();
    self.pipelines.canvas = try .init(self.gpu, .{
        .type = .canvas,
        .primitive = .triangles,
        .blend = true,
        .depth_test = false,
    });
    errdefer self.pipelines.canvas.deinit();
    self.pipelines.blit = try .init(self.gpu, .{
        .type = .blit,
        .primitive = .triangles,
        .blend = true,
        .depth_test = false,
    });
    errdefer self.pipelines.blit.deinit();

    // Create buffers
    self.buffers.constants = try .init(self.gpu, .constants, @sizeOf(Platform.Constants));
    errdefer self.buffers.constants.deinit();
}
pub fn deinit(self: *Self) void {
    self.buffers.constants.deinit();

    self.pipelines.uber_opaque.deinit();
    self.pipelines.uber_line.deinit();
    self.pipelines.canvas.deinit();
    self.pipelines.blit.deinit();
}
pub fn onPostUpdate(self: *Self) !void {
    try self.mesh.syncGPU();
    try self.texture.syncGPU();
}
pub fn onRender(self: *Self) !void {
    var encoder = nux.GPU.Encoder.init(self.gpu);
    defer encoder.deinit();

    const constants: Platform.Constants = .{
        .view = undefined,
        .proj = undefined,
        .screen_size = undefined,
        .time = 0,
    };
    try self.buffers.constants.update(0, @sizeOf(Platform.Constants), @ptrCast(&constants));

    try encoder.bindFramebuffer(null);
    try encoder.clearColor(0x0);
    try encoder.bindPipeline(&self.pipelines.uber_line);
    try encoder.bindBuffer(.constants_buffer, &self.buffers.constants);
    // try encoder.bindBuffer(.batches_buffer, &self.buffers.batches);
    // try encoder.bindBuffer(.transforms_buffer, &self.buffers.transforms);
    try encoder.bindBuffer(.vertices_buffer, &self.mesh.vertex_buffer);

    // var it = self.staticmesh.components.iterator();
    // while (it.next()) |entry| {}

    try encoder.submit();
}
