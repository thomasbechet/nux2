const std = @import("std");

pub const Span = struct {
    offset: usize,
    length: usize,
};

pub const FitStrategy = enum {
    first_fit,
    best_fit,
    worst_fit,
};

pub const SpanAllocator = struct {
    size: usize,
    freelist: std.ArrayList(Span),
    allocator: std.mem.Allocator,
    strategy: FitStrategy = .first_fit,

    pub fn init(allocator: std.mem.Allocator, size: usize, freelistCapa: usize) !SpanAllocator {
        var list = try std.ArrayList(Span).initCapacity(allocator, freelistCapa);
        try list.append(allocator, .{ .offset = 0, .length = size });
        return .{ .size = size, .freelist = list, .allocator = allocator };
    }

    pub fn setStrategy(self: *SpanAllocator, strategy: FitStrategy) void {
        self.strategy = strategy;
    }

    pub fn deinit(self: *SpanAllocator) void {
        self.freelist.deinit(self.allocator);
    }

    pub fn allocOld(self: *SpanAllocator, len: usize) ?Span {
        for (self.freelist.items, 0..) |span, i| {
            if (span.length >= len) {
                const out = Span{ .offset = span.offset, .length = len };
                if (span.length == len) {
                    _ = self.freelist.swapRemove(i);
                } else {
                    self.freelist.items[i] = .{
                        .offset = span.offset + len,
                        .length = span.length - len,
                    };
                }
                return out;
            }
        }
        return null;
    }

    pub fn alloc(self: *SpanAllocator, len: usize) ?Span {
        if (self.freelist.items.len == 0) return null;

        var best_index: ?usize = null;

        switch (self.strategy) {
            .first_fit => {
                for (self.freelist.items, 0..) |span, i| {
                    if (span.length >= len) {
                        best_index = i;
                        break;
                    }
                }
            },
            .best_fit => {
                var best_size: usize = std.math.maxInt(usize);
                for (self.freelist.items, 0..) |span, i| {
                    if (span.length >= len and span.length < best_size) {
                        best_size = span.length;
                        best_index = i;
                    }
                }
            },
            .worst_fit => {
                var worst_size: usize = 0;
                for (self.freelist.items, 0..) |span, i| {
                    if (span.length >= len and span.length > worst_size) {
                        worst_size = span.length;
                        best_index = i;
                    }
                }
            },
        }

        const i = best_index orelse return null;
        const span = self.freelist.items[i];

        const out = Span{ .offset = span.offset, .length = len };

        if (span.length == len) {
            _ = self.freelist.swapRemove(i);
        } else {
            self.freelist.items[i] = .{
                .offset = span.offset + len,
                .length = span.length - len,
            };
        }

        return out;
    }

    pub fn free(self: *SpanAllocator, span: Span) !void {
        // Find insertion index to keep sorted by offset
        var i: usize = 0;
        while (i < self.freelist.items.len and self.freelist.items[i].offset < span.offset) {
            i += 1;
        }
        try self.freelist.insert(self.allocator, i, span);

        // Coalesce with previous
        if (i > 0) {
            const prev = &self.freelist.items[i - 1];
            const curr = &self.freelist.items[i];
            if (prev.offset + prev.length == curr.offset) {
                prev.length += curr.length;
                _ = self.freelist.orderedRemove(i);
                i -= 1;
            }
        }

        // Coalesce with next
        if (i + 1 < self.freelist.items.len) {
            const curr = &self.freelist.items[i];
            const next = &self.freelist.items[i + 1];
            if (curr.offset + curr.length == next.offset) {
                curr.length += next.length;
                _ = self.freelist.orderedRemove(i + 1);
            }
        }
    }
};

test "basic alloc returns correct span" {
    var alloc = try SpanAllocator.init(std.testing.allocator, 100, 64);
    defer alloc.deinit();

    const s = alloc.alloc(20) orelse return error.TestFailed;
    try std.testing.expectEqual(@as(usize, 0), s.offset);
    try std.testing.expectEqual(@as(usize, 20), s.length);
}

test "free and reuse span" {
    var alloc = try SpanAllocator.init(std.testing.allocator, 100, 64);
    defer alloc.deinit();

    const a = alloc.alloc(30) orelse return error.TestFailed;
    const b = alloc.alloc(40) orelse return error.TestFailed;

    try alloc.free(a);

    const c = alloc.alloc(20) orelse return error.TestFailed;
    try std.testing.expectEqual(@as(usize, 0), c.offset);
    try std.testing.expectEqual(@as(usize, 20), c.length);

    _ = b; // silence unused warning
}

test "coalesce with next" {
    var alloc = try SpanAllocator.init(std.testing.allocator, 100, 64);
    defer alloc.deinit();

    const a = alloc.alloc(20) orelse return error.TestFailed; // [0,20)
    const b = alloc.alloc(30) orelse return error.TestFailed; // [20,50)

    try alloc.free(b);
    try alloc.free(a);

    // Should coalesce into [0,100)
    try std.testing.expectEqual(@as(usize, 1), alloc.freelist.items.len);
    const span = alloc.freelist.items[0];
    try std.testing.expectEqual(@as(usize, 0), span.offset);
    try std.testing.expectEqual(@as(usize, 100), span.length);
}

test "coalesce with previous" {
    var alloc = try SpanAllocator.init(std.testing.allocator, 100, 64);
    defer alloc.deinit();

    const a = alloc.alloc(20) orelse return error.TestFailed; // [0,20)
    const b = alloc.alloc(30) orelse return error.TestFailed; // [20,50)

    try alloc.free(a);
    try alloc.free(b);

    try std.testing.expectEqual(@as(usize, 1), alloc.freelist.items.len);
    const span = alloc.freelist.items[0];
    try std.testing.expectEqual(@as(usize, 0), span.offset);
    try std.testing.expectEqual(@as(usize, 100), span.length);
}

test "coalesce both sides" {
    var alloc = try SpanAllocator.init(std.testing.allocator, 100, 64);
    defer alloc.deinit();

    const a = alloc.alloc(20) orelse return error.TestFailed; // [0,20)
    const b = alloc.alloc(30) orelse return error.TestFailed; // [20,50)
    const c = alloc.alloc(10) orelse return error.TestFailed; // [50,60)

    try alloc.free(a);
    try alloc.free(c);
    try alloc.free(b); // should merge all three

    try std.testing.expectEqual(@as(usize, 1), alloc.freelist.items.len);
    const span = alloc.freelist.items[0];
    try std.testing.expectEqual(@as(usize, 0), span.offset);
    try std.testing.expectEqual(@as(usize, 100), span.length);
}
