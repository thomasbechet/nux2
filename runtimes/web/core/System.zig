extern fn system_timestamp() u64;

pub fn timestamp(_: *anyopaque) u64 {
    return system_timestamp();
}
pub fn memoryUsage(_: *anyopaque) ?f32 {
    return null;
}
