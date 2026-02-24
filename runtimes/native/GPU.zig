const std = @import("std");
const nux = @import("nux");
const gl = @import("gl");

const Self = @This();

const Platform = nux.Platform.GPU;

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
pub fn deinit(self: *Self) void {
    _ = self;
}

fn createTexture(ctx: *anyopaque, info: Platform.TextureInfo) anyerror!Platform.Handle {
    const self: *Self = @ptrCast(@alignCast(ctx));
    //         switch (info->type)
    // {
    //     case NUX_TEXTURE_IMAGE_RGBA:
    //         tex->internal_format = GL_RGBA8;
    //         tex->format          = GL_RGBA;
    //         break;
    //     case NUX_TEXTURE_IMAGE_INDEX:
    //         tex->internal_format = GL_R8UI;
    //         tex->format          = GL_RED_INTEGER;
    //         break;
    //     case NUX_TEXTURE_RENDER_TARGET:
    //         tex->internal_format = GL_RGBA8;
    //         tex->format          = GL_RGB;
    // }
    //
    // switch (info->filter)
    // {
    //     case NUX_GPU_TEXTURE_FILTER_LINEAR:
    //         tex->filtering = GL_LINEAR;
    //         break;
    //     case NUX_GPU_TEXTURE_FILTER_NEAREST:
    //         tex->filtering = GL_NEAREST;
    //         break;
    // }

    const texture = try self.allocator.create(TextureHandle);
    texture.internal_format = gl.RGBA8;
    texture.format = gl.RGBA;
    texture.filtering = gl.NEAREST;
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
fn deleteTexture(ctx: *anyopaque, handle: Platform.Handle) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const texture: *TextureHandle = @ptrCast(@alignCast(handle));
    gl.DeleteTextures(1, @ptrCast(&texture.handle));
    self.allocator.destroy(texture);
}
fn updateTexture(_: *anyopaque, _: Platform.Handle, _: u32, _: u32, _: u32, _: u32, _: []const u8) anyerror!void {}

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

fn createBuffer(ctx: *anyopaque, typ: Platform.BufferType, size: u64) anyerror!Platform.Handle {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const buffer = try self.allocator.create(BufferHandle);
    buffer.type = typ;

    buffer.type = switch (buffer.type) {
        .uniform => gl.UNIFORM_BUFFER,
        .storage => gl.SHADER_STORAGE_BUFFER,
    };

    gl.GenBuffers(1, &buffer.handle);
    gl.BindBuffer(buffer.type, buffer.handle);
    gl.BufferData(buffer.type, size, null, gl.DYNAMIC_DRAW);
    gl.BindBuffer(buffer.type, 0);
}
fn deleteBuffer(ctx: *anyopaque, handle: Platform.Handle) anyerror!void {}
fn updateBuffer(ctx: *anyopaque, handle: Platform.Handle, offset: u64, size: u64, data: []const f32) anyerror!void {}
