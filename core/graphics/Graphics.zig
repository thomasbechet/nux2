const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();
const Platform = nux.Platform.GPU;

pub const CommandBuffer = struct {
    const DataSlice = struct {
        start: usize,
        end: usize,
    };

    const Rectangle = struct {
        box: nux.Box2,
        color: u32 = 0,
        radius: u32 = 0,
        bevel: u32 = 0,
    };

    const Line = struct {
        start: nux.Vec2,
        end: nux.Vec2,
        color: u32 = 0,
    };

    const Text = struct {
        text: []const u8,
        color: u32 = 0,
        position: nux.Vec2 = .zero(),
    };

    const Blit = struct {
        source: nux.ID,
        box: nux.Box2,
        pos: nux.Vec2 = .zero(),
        scale: u32 = 1,
    };

    const Command = union(enum) {
        scissor: struct {
            box: nux.Box2,
        },
        blit: struct {
            source: nux.ID,
            box: nux.Box2,
            pos: nux.Vec2,
        },
        text: struct {
            data: DataSlice,
            position: nux.Vec2,
            color: u32,
        },
        line: struct {
            start: nux.Vec2,
            stop: nux.Vec2,
            color: u32,
        },
        rectangle: struct {
            box: nux.Box2,
            color: u32,
        },
        staticmesh: struct {
            id: nux.ID,
        },
        camera: struct {
            id: nux.ID,
        },
    };

    pub const GraphicsPass = struct {};

    allocator: std.mem.Allocator,
    commands: std.ArrayList(Command),
    data: std.ArrayList(u8),
    palette: std.ArrayList(nux.Vec4),

    pub fn init(allocator: std.mem.Allocator) CommandBuffer {
        return .{
            .allocator = allocator,
            .commands = .empty,
            .data = .empty,
            .palette = .empty,
        };
    }
    pub fn deinit(self: *CommandBuffer) void {
        self.commands.deinit(self.allocator);
        self.data.deinit(self.allocator);
        self.palette.deinit(self.allocator);
    }
    pub fn reset(self: *CommandBuffer) !void {
        self.commands.clearRetainingCapacity();
        self.data.clearRetainingCapacity();
    }

    pub fn scissor(self: *CommandBuffer, b: nux.Box2i) !void {
        try self.commands.append(self.allocator, .{
            .scissor = .{ .box = b },
        });
    }
    pub fn line(self: *CommandBuffer) !void {
        _ = self;
    }
    pub fn rectangle(self: *CommandBuffer, info: Rectangle) !void {
        try self.commands.append(self.allocator, .{
            .rectangle = .{
                .box = info.box,
                .color = info.color,
            },
        });
    }
    pub fn text(self: *CommandBuffer, info: Text) !void {
        const start = self.data.items.len;
        try self.data.appendSlice(self.allocator, info.text);
        try self.commands.append(self.allocator, .{
            .text = .{
                .data = .{ .start = start, .end = self.data.items.len },
                .color = 0,
            },
        });
    }
    pub fn blit(self: *CommandBuffer, info: Blit) !void {
        try self.commands.append(self.allocator, .{
            .blit = .{
                .source = info.source,
                .box = info.box,
                .pos = info.pos,
            },
        });
    }
    pub fn staticmesh(self: *CommandBuffer, id: nux.ID) !void {
        _ = self;
        _ = id;
    }
};
