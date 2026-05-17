const nux = @import("nux");
const std = @import("std");
const builtin = @import("builtin");

const Self = @This();

fn timestamp(_: *anyopaque) u64 {
    return @intCast(std.time.nanoTimestamp());
}
fn memoryUsage(_: *anyopaque) ?f32 {
    if (builtin.os.tag == .linux) {
        const file = std.fs.openFileAbsolute("/proc/self/status", .{}) catch return null;
        defer file.close();

        var buf: [4096]u8 = undefined;
        const n = file.readAll(&buf) catch return null;
        const content = buf[0..n];

        if (std.mem.indexOf(u8, content, "VmRSS:")) |pos| {
            const line = content[pos..std.mem.indexOfScalarPos(u8, content, pos, '\n').?];
            var it = std.mem.tokenizeScalar(u8, line, ' ');
            _ = it.next(); // VmRSS:
            while (it.next()) |tok| { // Skip spaces
                if (std.fmt.parseInt(u64, tok, 10)) |kb| {
                    const mb = @as(f32, @floatFromInt(kb)) / 1024.0;
                    return mb;
                } else |_| {}
            }
        }

        return null;
    } else if (builtin.os.tag == .windows) {
        // Using working set => not accurate...
        const windows = std.os.windows;
        const kernel32 = windows.kernel32;

        const counters = windows.GetProcessMemoryInfo(
            kernel32.GetCurrentProcess(),
        ) catch return null;

        // WorkingSetSize is in bytes
        const mb = @as(f32, @floatFromInt(counters.WorkingSetSize)) / (1024.0 * 1024.0);
        return mb;
    } else {
        return null;
    }
}

gpa: std.heap.DebugAllocator(.{
    .stack_trace_frames = 10,
}),

pub fn init() Self {
    return .{
        .gpa = .init,
    };
}
pub fn deinit(self: *Self) void {
    _ = self.gpa.deinit();
}
pub fn platform(self: *Self) nux.Platform.System {
    return .{
        .ptr = self,
        .vtable = &.{
            .timestamp = timestamp,
            .memory_usage = memoryUsage,
        },
    };
}
