const std = @import("std");

fn checkNode(ast: *std.zig.Ast, index: usize) void {
    const nodes = &ast.nodes;
    const node = nodes.get(index);
    if (node.tag == .fn_decl) {
        const lhs = nodes.get(@intFromEnum(node.data.node_and_node.@"0"));
        if (lhs.tag == .fn_proto_simple) {
            std.log.info("{}", .{lhs});
            // ast.fnProtoSimple(node.data.node_and_node.@"0");
        } else if (lhs.tag == .fn_proto_multi) {
            std.log.info("{}", .{ast.fnProtoMulti(lhs.data.node)});
        }
        std.log.info("{}", .{lhs.tag});
    }
}

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
        \\pub fn helloWorld() void {}
        \\pub fn func2(v: u32, v2: u32) ?void { _ = v; _ = v2; return null; }
    ;
    var ast = std.zig.Ast.parse(gpa.allocator(), src, .zig) catch {
        std.debug.print("failed to parse source file.", .{});
        return;
    };
    defer ast.deinit(gpa.allocator());

    std.log.info("node count : {}", .{ast.nodes.len});
    for (ast.rootDecls()) |index| {
        checkNode(&ast, @intFromEnum(index));
    }

    var buffer: [1024]u8 = undefined;
    var writer = file.writer(&buffer);
    const out: *std.Io.Writer = &writer.interface;
    try out.print(
        \\ pub const string = "{}";
    , .{ast.nodes.len});
    try out.flush();
}
