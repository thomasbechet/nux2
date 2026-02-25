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
