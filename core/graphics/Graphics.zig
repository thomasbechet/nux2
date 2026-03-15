const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Renderer = nux.Renderer;
const Platform = nux.Platform.GPU;

renderer: *nux.Renderer,
window: *nux.Window,
mesh: *nux.Mesh,
texture: *nux.Texture,
material: *nux.Material,
staticmesh: *nux.StaticMesh,
transform: *nux.Transform,

allocator: std.mem.Allocator,
pipelines: struct {
    uber_opaque: Renderer.Pipeline,
    uber_line: Renderer.Pipeline,
    canvas: Renderer.Pipeline,
    blit: Renderer.Pipeline,
},
buffers: struct {
    constants: Renderer.Buffer,
    batches: Renderer.Buffer,
    transforms: Renderer.Buffer,
},

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.allocator = core.platform.allocator;

    // Create pipelines
    self.pipelines.uber_opaque = try .init(self.renderer, .{
        .type = .uber,
        .primitive = .triangles,
        .blend = false,
        .depth_test = true,
    });
    errdefer self.pipelines.uber_opaque.deinit();
    self.pipelines.uber_line = try .init(self.renderer, .{
        .type = .uber,
        .primitive = .lines,
        .blend = false,
        .depth_test = true,
    });
    errdefer self.pipelines.uber_line.deinit();
    self.pipelines.canvas = try .init(self.renderer, .{
        .type = .canvas,
        .primitive = .triangles,
        .blend = true,
        .depth_test = false,
    });
    errdefer self.pipelines.canvas.deinit();
    self.pipelines.blit = try .init(self.renderer, .{
        .type = .blit,
        .primitive = .triangles,
        .blend = true,
        .depth_test = false,
    });
    errdefer self.pipelines.blit.deinit();

    // Create buffers
    self.buffers.constants = try .init(self.renderer, .constants, @sizeOf(Platform.Constants));
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
    try self.mesh.syncRenderer();
    try self.texture.syncRenderer();
}
pub fn onRender(self: *Self) !void {
    var encoder = nux.Renderer.Encoder.init(self.renderer);
    defer encoder.deinit();

    const constants: Platform.Constants = .{
        .view = undefined,
        .proj = undefined,
        .screen_size = undefined,
        .time = 0,
    };
    try self.buffers.constants.update(0, @sizeOf(Platform.Constants), @ptrCast(&constants));

    try encoder.bindFramebuffer(null);
    try encoder.viewport(0, 0, self.window.width, self.window.height);
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
