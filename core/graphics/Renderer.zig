const std = @import("std");
const nux = @import("../nux.zig");

const Self = @This();

pub const CommandBuffer = struct {
    const DataSlice = struct {
        start: usize,
        end: usize,
    };

    const Rectangle = struct {
        box: nux.Box2i,
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
        position: nux.Vec2i = .zero(),
    };

    const Blit = struct {
        source: nux.Box2i,
        position: nux.Vec2i = .zero(),
        scale: u32 = 1,
    };

    const Command = union(enum) {
        scissor: struct {
            box: nux.Box2i,
        },
        text: struct {
            data: DataSlice,
            position: nux.Vec2i,
            color: u32,
        },
        line: struct {
            start: nux.Vec2i,
            stop: nux.Vec2i,
            color: u32,
        },
        rectangle: struct {
            box: nux.Box2i,
            color: u32,
        },
        staticmesh: struct {
            id: nux.ID,
        },
        camera: struct {
            id: nux.ID,
        },
    };

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

    pub fn clear(self: *CommandBuffer) !void {
        self.commands.clearRetainingCapacity();
        self.data.clearRetainingCapacity();
    }
    pub fn reset(self: *CommandBuffer) !void {
        _ = self;
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
        _ = self;
        _ = info;
    }
    pub fn drawMesh(self: *CommandBuffer) !void {
        _ = self;
    }
    pub fn drawStaticMesh(self: *CommandBuffer, staticmesh: nux.ID) !void {
        _ = self;
        _ = staticmesh;
    }
};
