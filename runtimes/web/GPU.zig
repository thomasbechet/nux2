const nux = @import("nux");

const Platform = nux.Platform.GPU;

extern fn gpu_create_device() void;
extern fn gpu_delete_device() void;
extern fn gpu_create_pipeline() u32;
extern fn gpu_delete_pipeline(handle: u32) void;
extern fn gpu_create_texture(w: u32, h: u32) u32;
extern fn gpu_delete_texture(handle: u32) void;
extern fn gpu_update_texture(
    handle: u32,
    x: u32,
    y: u32,
    w: u32,
    h: u32,
    data: [*]const u8,
    len: usize,
) void;
extern fn gpu_create_buffer(size: u32) u32;
extern fn gpu_delete_buffer(handle: u32) void;
extern fn gpu_update_buffer(
    handle: u32,
    offset: u32,
    size: u32,
    data: [*]const u8,
    len: usize,
) void;
extern fn gpu_submit_commands(
    count: u32,
    commands: [*]const u8,
) void;

pub fn createDevice(_: *anyopaque) !void {
    gpu_create_device();
}
pub fn deleteDevice(_: *anyopaque) void {
    gpu_delete_device();
}

pub fn createPipeline(_: *anyopaque, _: Platform.PipelineInfo) !Platform.Handle {
    const handle = gpu_create_pipeline();
    return @ptrFromInt(handle);
}
pub fn deletePipeline(_: *anyopaque, handle: Platform.Handle) void {
    gpu_delete_pipeline(@intFromPtr(handle));
}

pub fn createTexture(_: *anyopaque, info: Platform.TextureInfo) !Platform.Handle {
    const handle = gpu_create_texture(info.width, info.height);
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
    gpu_update_texture(@intFromPtr(handle), x, y, w, h, data.ptr, data.len);
}

pub fn createBuffer(
    _: *anyopaque,
    _: Platform.BufferType,
    size: u32,
) !Platform.Handle {
    const handle = gpu_create_buffer(size);
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
    gpu_update_buffer(@intFromPtr(handle), offset, size, data.ptr, data.len);
}

pub fn submitCommands(
    _: *anyopaque,
    commands: []const Platform.Command,
) !void {
    gpu_submit_commands(commands.len, @ptrCast(commands.ptr));
}
