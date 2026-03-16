const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const GPU = nux.Platform.GPU;

pub const Framebuffer = struct {
    handle: GPU.Handle,
    renderer: *Self,
};

pub const Pipeline = struct {
    handle: GPU.Handle,
    renderer: *Self,

    pub fn init(renderer: *Self, info: GPU.PipelineInfo) !Pipeline {
        return .{
            .handle = try renderer.gpu.vtable.create_pipeline(renderer.gpu.ptr, info),
            .renderer = renderer,
        };
    }
    pub fn deinit(self: *Pipeline) void {
        self.renderer.gpu.vtable.delete_pipeline(self.renderer.gpu.ptr, self.handle);
    }
};

pub const Texture = struct {
    handle: GPU.Handle,
    renderer: *Self,

    pub fn init(renderer: *Self, info: GPU.TextureInfo) !Texture {
        return .{
            .handle = try renderer.gpu.vtable.create_texture(renderer.gpu.ptr, info),
            .renderer = renderer,
        };
    }
    pub fn deinit(self: *Texture) void {
        self.renderer.gpu.vtable.delete_texture(self.renderer.gpu.ptr, self.handle);
    }
    pub fn update(self: *Texture, x: u32, y: u32, w: u32, h: u32, data: []const u8) !void {
        try self.renderer.gpu.vtable.update_texture(
            self.renderer.gpu.ptr,
            self.handle,
            x,
            y,
            w,
            h,
            data,
        );
    }
};

pub const Buffer = struct {
    handle: GPU.Handle,
    renderer: *Self,

    pub fn init(renderer: *Self, typ: GPU.BufferType, size: u64) !Buffer {
        return .{
            .renderer = renderer,
            .handle = try renderer.gpu.vtable.create_buffer(renderer.gpu.ptr, typ, size),
        };
    }
    pub fn deinit(self: *Buffer) void {
        self.renderer.gpu.vtable.delete_buffer(self.renderer.gpu.ptr, self.handle);
    }
    pub fn update(self: *Buffer, offset: u64, size: u64, data: []const u8) !void {
        try self.renderer.gpu.vtable.update_buffer(
            self.renderer.gpu.ptr,
            self.handle,
            offset,
            size,
            data,
        );
    }
};

pub const CommandBuffer = struct {
    const CanvasPass = struct {
        scissor: nux.Vec4,
        clear_color: ?nux.Vec4,
        command_count: u32,
    };

    const DataSlice = struct {
        start: usize,
        end: usize,
    };

    const RenderPass = struct {
        viewport: nux.Vec4,
        target: nux.ID,
        command_count: u32,
        camera: nux.ID,
        clear_color: ?nux.Vec4,
    };

    const BeginPass = union(enum) {
        canvas: CanvasPass,
        render: RenderPass,
    };

    const Rectangle = struct {
        box: nux.Vec4,
        color: nux.Vec4,
        radius: f32,
    };

    const Line = struct {
        start: nux.Vec2,
        end: nux.Vec2,
    };

    const Text = struct {
        text: DataSlice,
        color: nux.Vec4,
    };

    const Command = union(enum) {
        begin_pass: BeginPass,
        text: Text,
        rectangle: Rectangle,
        staticmesh: nux.ID,
    };

    allocator: std.mem.Allocator,
    commands: std.ArrayList(Command),
    data: std.ArrayList(u8),

    pub fn drawStaticMesh(self: *CommandBuffer, id: nux.ID) !void {}
    pub fn drawLine(self: *CommandBuffer) !void {}
    pub fn drawRectangle(self: *CommandBuffer) !void {}
    pub fn drawText(self: *CommandBuffer) !void {}
    pub fn blit(self: *CommandBuffer) !void {}
};

pub const Encoder = struct {
    renderer: *Self,
    allocator: std.mem.Allocator,
    commands: std.ArrayList(GPU.Command),

    pub fn init(renderer: *Self) Encoder {
        return .{
            .renderer = renderer,
            .allocator = renderer.allocator,
            .commands = .empty,
        };
    }
    pub fn deinit(self: *Encoder) void {
        self.commands.deinit(self.renderer.allocator);
    }
    pub fn submit(self: *Encoder) !void {
        try self.renderer.gpu.vtable.submit_commands(self.renderer.gpu.ptr, self.commands.items);
        self.commands.clearRetainingCapacity();
    }

    pub fn bindFramebuffer(self: *Encoder, framebuffer: ?*const Framebuffer) !void {
        var handle: ?GPU.Handle = null;
        if (framebuffer) |fb| {
            handle = fb.handle;
        }
        try self.commands.append(self.allocator, .{
            .bind_framebuffer = .{ .framebuffer = handle },
        });
    }
    pub fn bindPipeline(self: *Encoder, pipeline: *const Pipeline) !void {
        try self.commands.append(self.allocator, .{
            .bind_pipeline = .{ .pipeline = pipeline.handle },
        });
    }
    pub fn bindTexture(self: *Encoder, descriptor: GPU.Descriptor, texture: *const Texture) !void {
        try self.commands.append(self.allocator, .{
            .bind_texture = .{ .texture = texture.handle, .descriptor = descriptor },
        });
    }
    pub fn bindBuffer(self: *Encoder, descriptor: GPU.Descriptor, buffer: *const Buffer) !void {
        try self.commands.append(self.allocator, .{
            .bind_buffer = .{ .buffer = buffer.handle, .descriptor = descriptor },
        });
    }
    pub fn pushU32(self: *Encoder, descriptor: GPU.Descriptor, value: u32) !void {
        try self.commands.append(self.allocator, .{
            .push_u32 = .{ .value = value, .descriptor = descriptor },
        });
    }
    pub fn pushF32(self: *Encoder, descriptor: GPU.Descriptor, value: f32) !void {
        try self.commands.append(self.allocator, .{
            .push_f32 = .{ .value = value, .descriptor = descriptor },
        });
    }
    pub fn draw(self: *Encoder, count: u32) !void {
        try self.commands.append(self.allocator, .{
            .draw = .{ .count = count },
        });
    }
    pub fn drawFullQuad(self: *Encoder) !void {
        try self.draw(3); // Draw full screen triangle
    }
    pub fn clearColor(self: *Encoder, color: u32) !void {
        try self.commands.append(self.allocator, .{ .clear_color = .{ .color = color } });
    }
    pub fn clearDepth(self: *Encoder) !void {
        try self.commands.append(self.allocator, .{.clear_depth});
    }
    pub fn viewport(self: *Encoder, x: i32, y: i32, w: u32, h: u32) !void {
        try self.commands.append(self.allocator, .{ .viewport = .{
            .x = x,
            .y = y,
            .width = w,
            .height = h,
        } });
    }
};

gpu: GPU,
allocator: std.mem.Allocator,

pub fn init(self: *Self, core: *const nux.Core) !void {
    self.gpu = core.platform.gpu;
    self.allocator = core.platform.allocator;
    try self.gpu.vtable.create_device(self.gpu.ptr);
}
pub fn deinit(self: *Self) void {
    self.gpu.vtable.delete_device(self.gpu.ptr);
}
