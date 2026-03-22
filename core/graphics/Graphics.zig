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
        box: nux.Box2i,
        color: nux.Color = .white,
        radius: u32 = 0,
        bevel: u32 = 0,
    };

    const Line = struct {
        start: nux.Vec2i,
        end: nux.Vec2i,
        color: u32 = 0,
    };

    const Text = struct {
        text: []const u8,
        color: nux.Color = .white,
        pos: nux.Vec2i = .zero(),
        scale: u32 = 1,
    };

    const Blit = struct {
        source: nux.ID,
        box: nux.Box2i,
        pos: nux.Vec2i = .zero(),
        scale: u32 = 1,
    };

    const Command = union(enum) {
        scissor: struct {
            box: ?nux.Box2i,
        },
        blit: Blit,
        text: struct {
            data: DataSlice,
            position: nux.Vec2i,
            color: nux.Color,
            scale: u32,
        },
        line: Line,
        rectangle: Rectangle,
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
    pub fn reset(self: *CommandBuffer) !void {
        self.commands.clearRetainingCapacity();
        self.data.clearRetainingCapacity();
    }

    pub fn dataSlice(self: *const CommandBuffer, slice: DataSlice) []const u8 {
        return self.data.items[slice.start..slice.end];
    }
    pub fn scissor(self: *CommandBuffer, b: ?nux.Box2i) !void {
        try self.commands.append(self.allocator, .{
            .scissor = .{ .box = b },
        });
    }
    pub fn line(self: *CommandBuffer) !void {
        _ = self;
    }
    pub fn rectangle(self: *CommandBuffer, info: Rectangle) !void {
        try self.commands.append(self.allocator, .{
            .rectangle = info,
        });
    }
    pub fn text(self: *CommandBuffer, info: Text) !void {
        const start = self.data.items.len;
        try self.data.appendSlice(self.allocator, info.text);
        try self.commands.append(self.allocator, .{
            .text = .{
                .data = .{ .start = start, .end = self.data.items.len },
                .position = info.pos,
                .color = info.color,
                .scale = info.scale,
            },
        });
    }
    pub fn blit(self: *CommandBuffer, info: Blit) !void {
        try self.commands.append(self.allocator, .{
            .blit = info,
        });
    }
    pub fn staticmesh(self: *CommandBuffer, id: nux.ID) !void {
        _ = self;
        _ = id;
    }
};
