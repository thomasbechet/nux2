const std = @import("std");
const nux = @import("nux");
const gl = @import("gl");

const Self = @This();

const Platform = nux.Platform.GPU;

const PipelineHandle = struct {
    handle: gl.uint = 0,
    type: Platform.PipelineType,
    blend: gl.boolean,
    depth_test: gl.boolean,
    primitive: gl.uint,
    program: gl.uint,
    indices: [Platform.Descriptor.max]gl.uint,
    locations: [Platform.Descriptor.max]gl.uint,
    units: [Platform.Descriptor.max]gl.uint,
};

const FramebufferHandle = struct {
    handle: gl.uint = 0,
};

const TextureHandle = struct {
    handle: gl.uint = 0,
    internal_format: gl.int,
    format: gl.uint,
    filtering: gl.int,
};

const BufferHandle = struct {
    handle: gl.uint = 0,
    type: gl.uint,
};

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

fn compileShader(self: *Self, source: []const u8, shader_type: gl.uint) !gl.uint {
    const handle = gl.CreateShader(shader_type);
    errdefer gl.DeleteShader(handle);
    gl.ShaderSource(handle, 1, &.{source.ptr}, &.{source.len});
    gl.CompileShader(handle);
    var success: gl.int = 0;
    gl.GetShaderiv(handle, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        var max_length: gl.int = 0;
        gl.GetShaderiv(handle, gl.INFO_LOG_LENGTH, &max_length);
        const log = self.allocator.alloc(gl.char, max_length);
        defer self.allocator.free(log);
        gl.GetShaderInfoLog(handle, max_length, &max_length, log);
        std.log.err("failed to compile shader {s}", .{log});
        return error.ShaderCompilation;
    }
    return handle;
}
fn compileProgram(self: *Self, vertex: []const u8, fragment: []const u8) !gl.uint {
    const vertex_shader = try self.compileShader(vertex, gl.VERTEX_SHADER);
    defer gl.DeleteShader(vertex_shader);
    const fragment_shader = try self.compileShader(fragment, gl.FRAGMENT_SHADER);
    defer gl.DeleteShader(fragment_shader);

    const handle = gl.CreateProgram();
    errdefer gl.DeleteProgram(handle);
    gl.AttachShader(handle, vertex_shader);
    gl.AttachShader(handle, fragment_shader);
    gl.LinkProgram(handle);
    var success: gl.int = 0;
    gl.GetProgramiv(handle, gl.LINK_STATUS, &success);
    if (success == gl.FALSE) {
        var max_length: gl.int = 0;
        gl.GetProgramiv(handle, gl.INFO_LOG_LENGTH, &max_length);
        const log = self.allocator.alloc(gl.char, max_length);
        defer self.allocator.free(log);
        gl.GetProgramInfoLog(handle, max_length, &max_length, log);
        std.log.err("failed to link program {s}", .{log});
        return error.ProgramLink;
    }
    return handle;
}

fn createPipeline(ctx: *anyopaque, info: Platform.PipelineInfo) anyerror!Platform.Handle {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const pipeline = try self.allocator.create(PipelineHandle);
    pipeline.type = info.type;
    pipeline.blend = if (info.blend) gl.TRUE else gl.FALSE;
    pipeline.depth_test = if (info.depth_test) gl.TRUE else gl.FALSE;
    pipeline.primitive = switch(info.primitive) {
        .triangles => gl.TRIANGLES,
        .lines => gl.LINES,
        .points => gl.POINTS,
    };
    return pipeline;
}
fn deletePipeline(ctx: *anyopaque, handle: Platform.Handle) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const pipeline: *PipelineHandle = @ptrCast(@alignCast(handle));
    gl.DeleteProgram(pipeline.handle);
    self.allocator.destroy(pipeline);
}

fn createFramebuffer(ctx: *anyopaque, texture: Platform.Handle) anyerror!Platform.Handle {
    _ = ctx;
    _ = texture;
    // const self: *Self = @ptrCast(@alignCast(ctx));
    // const framebuffer = try self.allocator.create(FramebufferHandle);
}
fn deleteFramebuffer(_: *anyopaque, _: Platform.Handle) void {}

fn createTexture(ctx: *anyopaque, info: Platform.TextureInfo) anyerror!Platform.Handle {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const texture = try self.allocator.create(TextureHandle);

    switch (info.type) {
        .image_rgba => {
            texture.internal_format = gl.RGBA8;
            texture.format = gl.RGBA;
        },
        .image_indexed => {
            texture.internal_format = gl.R8UI;
            texture.format = gl.RED_INTEGER;
        },
        .render_target => {
            texture.internal_format = gl.RGBA8;
            texture.format = gl.RGB;
        },
    }
    texture.filtering = switch (info.filter) {
        .linear => gl.LINEAR,
        .nearest => gl.NEAREST,
    };
    gl.GenTextures(1, @ptrCast(&texture.handle));
    gl.BindTexture(gl.TEXTURE_2D, texture.handle);
    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        texture.internal_format,
        @intCast(info.width),
        @intCast(info.height),
        0,
        texture.format,
        gl.UNSIGNED_BYTE,
        null,
    );
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, texture.filtering);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, texture.filtering);
    gl.BindTexture(gl.TEXTURE_2D, 0);

    return texture;
}
fn deleteTexture(ctx: *anyopaque, handle: Platform.Handle) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const texture: *TextureHandle = @ptrCast(@alignCast(handle));
    gl.DeleteTextures(1, @ptrCast(&texture.handle));
    self.allocator.destroy(texture);
}
fn updateTexture(_: *anyopaque, handle: Platform.Handle, x: u32, y: u32, w: u32, h: u32, data: []const u8) anyerror!void {
    const texture: *TextureHandle = @ptrCast(@alignCast(handle));
    gl.BindTexture(gl.TEXTURE_2D, texture.handle);
    gl.TexSubImage2D(
        gl.TEXTURE_2D,
        0,
        @intCast(x),
        @intCast(y),
        @intCast(w),
        @intCast(h),
        texture.format,
        gl.UNSIGNED_BYTE,
        data.ptr,
    );
    gl.BindTexture(gl.TEXTURE_2D, 0);
}

fn createBuffer(ctx: *anyopaque, typ: Platform.BufferType, size: u64) anyerror!Platform.Handle {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const buffer = try self.allocator.create(BufferHandle);

    buffer.type = switch (typ) {
        .uniform => gl.UNIFORM_BUFFER,
        .storage => gl.SHADER_STORAGE_BUFFER,
    };

    gl.GenBuffers(1, @ptrCast(&buffer.handle));
    gl.BindBuffer(buffer.type, buffer.handle);
    gl.BufferData(buffer.type, @intCast(size), null, gl.DYNAMIC_DRAW);
    gl.BindBuffer(buffer.type, 0);

    return buffer;
}
fn deleteBuffer(ctx: *anyopaque, handle: Platform.Handle) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const buffer: *BufferHandle = @ptrCast(@alignCast(handle));
    gl.DeleteBuffers(1, @ptrCast(&buffer.handle));
    self.allocator.destroy(buffer);
}
fn updateBuffer(_: *anyopaque, handle: Platform.Handle, offset: u64, size: u64, data: []const f32) anyerror!void {
    const buffer: *BufferHandle = @ptrCast(@alignCast(handle));

    gl.BindBuffer(buffer.type, buffer.handle);
    gl.BufferSubData(buffer.type, @intCast(offset), @intCast(size), data.ptr);
    gl.BindBuffer(buffer.type, 0);
}

pub fn platform(self: *Self) nux.Platform.GPU {
    return .{ .ptr = self, .vtable = &.{
        .create_texture = createTexture,
        .delete_texture = deleteTexture,
        .update_texture = updateTexture,
        .create_buffer = createBuffer,
        .delete_buffer = deleteBuffer,
        .update_buffer = updateBuffer,
    } };
}
