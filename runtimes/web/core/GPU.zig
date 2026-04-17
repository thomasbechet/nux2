const nux = @import("nux");

const Platform = nux.Platform.GPU;

extern fn gpu_create_device() void;
extern fn gpu_delete_device() void;
extern fn gpu_create_pipeline(
    typ: u32,
    primitive: u32,
    blend: bool,
    depth_test: bool,
) u32;
extern fn gpu_delete_pipeline(handle: u32) void;
extern fn gpu_create_texture(
    w: u32,
    h: u32,
    filtering: nux.Texture.Filtering,
    type: nux.Texture.Type,
) u32;
extern fn gpu_delete_texture(handle: u32) void;
extern fn gpu_update_texture(
    handle: u32,
    x: u32,
    y: u32,
    w: u32,
    h: u32,
    data: [*]const u8,
) void;
extern fn gpu_create_buffer(buffer_type: u32, size: u32) u32;
extern fn gpu_delete_buffer(handle: u32) void;
extern fn gpu_update_buffer(
    handle: u32,
    offset: u32,
    size: u32,
    data: [*]const u8,
) void;
extern fn gpu_submit_commands(
    count: u32,
    commands: [*]const u8,
    command_size: u32,
) void;

pub fn createDevice(_: *anyopaque) !void {
    gpu_create_device();
}
pub fn deleteDevice(_: *anyopaque) void {
    gpu_delete_device();
}

pub fn createPipeline(_: *anyopaque, info: Platform.PipelineInfo) !Platform.Handle {
    const handle = gpu_create_pipeline(
        @intFromEnum(info.type),
        @intFromEnum(info.primitive),
        info.blend,
        info.depth_test,
    );
    return @ptrFromInt(handle);
}
pub fn deletePipeline(_: *anyopaque, handle: Platform.Handle) void {
    gpu_delete_pipeline(@intFromPtr(handle));
}

pub fn createTexture(_: *anyopaque, info: Platform.TextureInfo) !Platform.Handle {
    const handle = gpu_create_texture(
        info.width,
        info.height,
        info.filter,
        info.type,
    );
    return @ptrFromInt(handle);
}
pub fn deleteTexture(_: *anyopaque, handle: Platform.Handle) void {
    gpu_delete_texture(@intFromPtr(handle));
}
pub fn updateTexture(
    _: *anyopaque,
    handle: Platform.Handle,
    x: u32,
    y: u32,
    w: u32,
    h: u32,
    data: []const u8,
) !void {
    gpu_update_texture(
        @intFromPtr(handle),
        x,
        y,
        w,
        h,
        data.ptr,
    );
}

pub fn createBuffer(
    _: *anyopaque,
    buffer_type: Platform.BufferType,
    size: u32,
) !Platform.Handle {
    const handle = gpu_create_buffer(
        @intFromEnum(buffer_type),
        size,
    );
    return @ptrFromInt(handle);
}
pub fn deleteBuffer(_: *anyopaque, handle: Platform.Handle) void {
    gpu_delete_buffer(@intFromPtr(handle));
}
pub fn updateBuffer(
    _: *anyopaque,
    handle: Platform.Handle,
    offset: u32,
    size: u32,
    data: []const u8,
) !void {
    gpu_update_buffer(
        @intFromPtr(handle),
        offset,
        size,
        data.ptr,
    );
}

pub fn submitCommands(
    _: *anyopaque,
    commands: []const Platform.Command,
) !void {
    gpu_submit_commands(
        commands.len,
        @ptrCast(commands.ptr),
        @sizeOf(Platform.Command),
    );
}
