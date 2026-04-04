const std = @import("std");

pub fn fromType(comptime T: type) u32 {
    return std.hash.Fnv1a_32.hash(@typeName(T));
}
