const nux = @import("nux");
const std = @import("std");

fn ramUsage(_: *anyopaque) ?f64 {
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
                const mb = @as(f64, @floatFromInt(kb)) / 1024.0;
                return mb;
            } else |_| {}
        }
    }

    return null;
}

pub const platform = nux.Platform.System {
    .ptr = undefined,
    .vtable = &.{
        .ram_usage = ramUsage,
    },
};
