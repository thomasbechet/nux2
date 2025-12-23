const std = @import("std");

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const output = args.next().?;
    const file = try std.fs.cwd().createFile(output, .{});
    defer file.close();
}
