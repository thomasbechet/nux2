const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();
    const output = args.next().?;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const file = try std.fs.cwd().createFile(output, .{});
    defer file.close();

    const src =
        \\const std = @import("std");
        \\
        \\pub const Player = struct {
        \\    x: i32,
        \\    score: i32 = 0,
        \\
        \\    pub fn init(self: *@This()) void {
        \\        self.score = 0;
        \\    }
        \\    pub fn print(self: @This()) void {
        \\        std.debug.print("player: {}\n", .{self.score});
        \\    }
        \\};
    ;
    var ast = std.zig.Ast.parse(gpa.allocator(), src, .zig) catch {
        std.debug.print("failed to parse source file.", .{});
        return;
    };
    defer ast.deinit(gpa.allocator());

    var buffer: [1024]u8 = undefined;
    var writer = file.writer(&buffer);
    const out: *std.Io.Writer = &writer.interface;
    try out.print(
        \\ pub const string = "{}";
    , .{ast.nodes.len});
    try out.flush();
}
