const std = @import("std");
const nux = @import("nux");
const gl = @import("gl");

const Self = @This();

const Platform = nux.Platform.GPU;

const PipelineHandle = struct {
    type: Platform.PipelineType,
    blend: bool,
    depth_test: bool,
    primitive: gl.uint,
    program: gl.uint,
    indices: [Platform.Descriptor.max]gl.uint,
    locations: [Platform.Descriptor.max]gl.int,
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

const shader_uber_vertex = @embedFile("shaders/uber.vert");
const shader_uber_fragment = @embedFile("shaders/uber.frag");
const shader_canvas_vertex = @embedFile("shaders/canvas.vert");
const shader_canvas_fragment = @embedFile("shaders/canvas.frag");
const shader_blit_vertex = @embedFile("shaders/blit.vert");
const shader_blit_fragment = @embedFile("shaders/blit.frag");

allocator: std.mem.Allocator,
active_pipeline: ?*PipelineHandle,
empty_vao: gl.uint,

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .active_pipeline = null,
        .empty_vao = 0,
    };
}

fn compileShader(self: *Self, source: []const u8, shader_type: gl.uint) !gl.uint {
    const handle = gl.CreateShader(shader_type);
    errdefer gl.DeleteShader(handle);
    gl.ShaderSource(handle, 1, &.{source.ptr}, &.{@intCast(source.len)});
    gl.CompileShader(handle);
    var success: gl.int = 0;
    gl.GetShaderiv(handle, gl.COMPILE_STATUS, @ptrCast(&success));
    if (success == gl.FALSE) {
        var max_length: gl.int = 0;
        gl.GetShaderiv(handle, gl.INFO_LOG_LENGTH, @ptrCast(&max_length));
        const log = try self.allocator.alloc(gl.char, @intCast(max_length));
        defer self.allocator.free(log);
        gl.GetShaderInfoLog(handle, max_length, &max_length, @ptrCast(log.ptr));
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
    gl.GetProgramiv(handle, gl.LINK_STATUS, @ptrCast(&success));
    if (success == gl.FALSE) {
        var max_length: gl.int = 0;
        gl.GetProgramiv(handle, gl.INFO_LOG_LENGTH, @ptrCast(&max_length));
        const log = try self.allocator.alloc(gl.char, @intCast(max_length));
        defer self.allocator.free(log);
        gl.GetProgramInfoLog(handle, max_length, &max_length, @ptrCast(log.ptr));
        std.log.err("failed to link program {s}", .{log});
        return error.ProgramLink;
    }
    return handle;
}
fn createDevice(ctx: *anyopaque) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    gl.GenVertexArrays(1, @ptrCast(&self.empty_vao));
}
fn deleteDevice(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    gl.DeleteVertexArrays(1, @ptrCast(&self.empty_vao));
}

fn createPipeline(ctx: *anyopaque, info: Platform.PipelineInfo) anyerror!Platform.Handle {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const pipeline = try self.allocator.create(PipelineHandle);
    pipeline.type = info.type;
    pipeline.blend = info.blend;
    pipeline.depth_test = info.depth_test;
    pipeline.primitive = switch (info.primitive) {
        .triangles => gl.TRIANGLES,
        .lines => gl.LINES,
        .points => gl.POINTS,
    };
    switch (info.type) {
        .uber => {
            pipeline.program = try self.compileProgram(shader_uber_vertex, shader_uber_fragment);

            var index: gl.uint = 0;
            index = gl.GetProgramResourceIndex(pipeline.program, gl.UNIFORM_BLOCK, "ConstantBlock");
            gl.UniformBlockBinding(pipeline.program, index, 1);
            index = gl.GetProgramResourceIndex(pipeline.program, gl.SHADER_STORAGE_BLOCK, "BatchBlock");
            gl.UniformBlockBinding(pipeline.program, index, 2);
            index = gl.GetProgramResourceIndex(pipeline.program, gl.SHADER_STORAGE_BLOCK, "VertexBlock");
            gl.UniformBlockBinding(pipeline.program, index, 3);
            index = gl.GetProgramResourceIndex(pipeline.program, gl.SHADER_STORAGE_BLOCK, "TransformBlock");
            gl.UniformBlockBinding(pipeline.program, index, 4);

            pipeline.indices[@intFromEnum(Platform.Descriptor.constants_buffer)] = 1;
            pipeline.indices[@intFromEnum(Platform.Descriptor.batches_buffer)] = 2;
            pipeline.indices[@intFromEnum(Platform.Descriptor.vertices_buffer)] = 3;
            pipeline.indices[@intFromEnum(Platform.Descriptor.transforms_buffer)] = 4;

            pipeline.locations[@intFromEnum(Platform.Descriptor.texture)] = gl.GetUniformLocation(pipeline.program, "texture0");
            pipeline.locations[@intFromEnum(Platform.Descriptor.batch_index)] = gl.GetUniformLocation(pipeline.program, "batchIndex");

            pipeline.units[@intFromEnum(Platform.Descriptor.texture)] = 0;
        },
        .canvas => {
            pipeline.program = try self.compileProgram(shader_canvas_vertex, shader_canvas_fragment);

            var index: gl.uint = 0;
            index = gl.GetProgramResourceIndex(pipeline.program, gl.UNIFORM_BLOCK, "ConstantBlock");
            gl.UniformBlockBinding(pipeline.program, index, 1);
            index = gl.GetProgramResourceIndex(pipeline.program, gl.SHADER_STORAGE_BLOCK, "BatchBlock");
            gl.UniformBlockBinding(pipeline.program, index, 2);
            index = gl.GetProgramResourceIndex(pipeline.program, gl.SHADER_STORAGE_BLOCK, "QuadBlock");
            gl.UniformBlockBinding(pipeline.program, index, 3);

            pipeline.indices[@intFromEnum(Platform.Descriptor.constants_buffer)] = 1;
            pipeline.indices[@intFromEnum(Platform.Descriptor.batches_buffer)] = 2;
            pipeline.indices[@intFromEnum(Platform.Descriptor.quads_buffer)] = 3;

            pipeline.locations[@intFromEnum(Platform.Descriptor.texture)] = gl.GetUniformLocation(pipeline.program, "texture0");
            pipeline.locations[@intFromEnum(Platform.Descriptor.batch_index)] = gl.GetUniformLocation(pipeline.program, "batchIndex");

            pipeline.units[@intFromEnum(Platform.Descriptor.texture)] = 0;
        },
        .blit => {
            pipeline.program = try self.compileProgram(shader_blit_vertex, shader_blit_fragment);

            pipeline.locations[@intFromEnum(Platform.Descriptor.texture)] = gl.GetUniformLocation(pipeline.program, "texture0");
            pipeline.locations[@intFromEnum(Platform.Descriptor.texture_width)] = gl.GetUniformLocation(pipeline.program, "textureWidth");
            pipeline.locations[@intFromEnum(Platform.Descriptor.texture_height)] = gl.GetUniformLocation(pipeline.program, "textureHeight");

            pipeline.units[@intFromEnum(Platform.Descriptor.texture)] = 0;
        },
    }
    return pipeline;
}
fn deletePipeline(ctx: *anyopaque, handle: Platform.Handle) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const pipeline: *PipelineHandle = @ptrCast(@alignCast(handle));
    gl.DeleteProgram(pipeline.program);
    self.allocator.destroy(pipeline);
}

fn createFramebuffer(ctx: *anyopaque, texture: Platform.Handle) anyerror!Platform.Handle {
    _ = texture;
    const self: *Self = @ptrCast(@alignCast(ctx));
    const framebuffer = try self.allocator.create(FramebufferHandle);
    return framebuffer;
}
fn deleteFramebuffer(ctx: *anyopaque, handle: Platform.Handle) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const framebuffer: *FramebufferHandle = @ptrCast(@alignCast(handle));
    self.allocator.destroy(framebuffer);
}

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
        .constants => gl.UNIFORM_BUFFER,
        .batches, .quads, .transforms, .vertices => gl.SHADER_STORAGE_BUFFER,
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
fn updateBuffer(_: *anyopaque, handle: Platform.Handle, offset: u64, size: u64, data: []const u8) anyerror!void {
    const buffer: *BufferHandle = @ptrCast(@alignCast(handle));

    gl.BindBuffer(buffer.type, buffer.handle);
    gl.BufferSubData(buffer.type, @intCast(offset), @intCast(size), data.ptr);
    gl.BindBuffer(buffer.type, 0);
}

fn submitCommands(ctx: *anyopaque, commands: []const Platform.Command) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    for (commands) |command| {
        switch (command) {
            .bind_framebuffer => |cmd| {
                if (cmd.framebuffer) |handle| {
                    const framebuffer: *FramebufferHandle = @ptrCast(@alignCast(handle));
                    gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer.handle);
                } else {
                    gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
                }
            },
            .bind_pipeline => |cmd| {
                const pipeline: *PipelineHandle = @ptrCast(@alignCast(cmd.pipeline));
                gl.UseProgram(pipeline.program);
                if (pipeline.depth_test) {
                    gl.Enable(gl.DEPTH_TEST);
                } else {
                    gl.Disable(gl.DEPTH_TEST);
                }
                if (pipeline.blend) {
                    gl.Enable(gl.BLEND);
                    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
                } else {
                    gl.Disable(gl.BLEND);
                }
                if (pipeline.type == .uber) {
                    gl.Enable(gl.MULTISAMPLE);
                }
                self.active_pipeline = pipeline;
            },
            .bind_buffer => |cmd| {
                const buffer: *BufferHandle = @ptrCast(@alignCast(cmd.buffer));
                const index = self.active_pipeline.?.indices[@intFromEnum(cmd.descriptor)];
                gl.BindBufferBase(buffer.type, index, buffer.handle);
            },
            .bind_texture => |cmd| {
                const texture: *TextureHandle = @ptrCast(@alignCast(cmd.texture));
                const unit = self.active_pipeline.?.units[@intFromEnum(cmd.descriptor)];
                const location = self.active_pipeline.?.locations[@intFromEnum(cmd.descriptor)];
                gl.ActiveTexture(gl.TEXTURE0 + unit);
                gl.BindTexture(gl.TEXTURE_2D, texture.handle);
                gl.Uniform1i(location, @intCast(unit));
            },
            .push_u32 => |cmd| {
                const location = self.active_pipeline.?.locations[@intFromEnum(cmd.descriptor)];
                gl.Uniform1ui(location, cmd.value);
            },
            .push_f32 => |cmd| {
                const location = self.active_pipeline.?.locations[@intFromEnum(cmd.descriptor)];
                gl.Uniform1f(location, cmd.value);
            },
            .draw => |cmd| {
                gl.BindVertexArray(self.empty_vao);
                gl.DrawArrays(self.active_pipeline.?.primitive, 0, @intCast(cmd.count));
                gl.BindVertexArray(0);
            },
            .clear_color => |cmd| {
                // nux_f32_t clear[4];
                // hex_to_linear(cmd->clear_color.color, clear);
                // const clear: [4]f32 = .{ cmd.color}
                _ = cmd;
                gl.ClearColor(0, 0, 0, 1);
                gl.Clear(gl.COLOR_BUFFER_BIT);
            },
            .clear_depth => {
                gl.Clear(gl.DEPTH_BUFFER_BIT);
            },
            .viewport => |cmd| {
                const y = @as(i32, @intCast(cmd.height)) - (cmd.y + @as(i32, @intCast(cmd.height)));
                gl.Viewport(cmd.x, y, @intCast(cmd.width), @intCast(cmd.height));
                gl.Enable(gl.SCISSOR_TEST);
                gl.Scissor(cmd.x, y, @intCast(cmd.width), @intCast(cmd.height));
            },
        }
    }
}

pub fn platform(self: *Self) nux.Platform.GPU {
    return .{ .ptr = self, .vtable = &.{
        .create_device = createDevice,
        .delete_device = deleteDevice,
        .create_pipeline = createPipeline,
        .delete_pipeline = deletePipeline,
        .create_framebuffer = createFramebuffer,
        .delete_framebuffer = deleteFramebuffer,
        .create_texture = createTexture,
        .delete_texture = deleteTexture,
        .update_texture = updateTexture,
        .create_buffer = createBuffer,
        .delete_buffer = deleteBuffer,
        .update_buffer = updateBuffer,
        .submit_commands = submitCommands,
    } };
}
