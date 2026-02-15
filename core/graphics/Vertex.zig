pub const Primitive = enum(u32) {
    triangles = 0,
    lines = 1,
    points = 2,
};
pub const Attributes = packed struct(u32) {
    position: bool = false,
    texcoord: bool = false,
    color: bool = false,
    padding: u29 = undefined,
};
pub const Layout = struct {
    stride: u8 = 0,
    position: ?u8 = null,
    texcoord: ?u8 = null,
    color: ?u8 = null,

    pub fn make(attributes: Attributes) Layout {
        var layout: Layout = .{};
        if (attributes.position) {
            layout.position = layout.stride;
            layout.stride += 3;
        }
        if (attributes.texcoord) {
            layout.texcoord = layout.stride;
            layout.stride += 2;
        }
        if (attributes.color) {
            layout.color = layout.stride;
            layout.stride += 3;
        }
        return layout;
    }
    fn primitive(self: Layout) Attributes {
        return .{ .position = self.position != null, .texcoord = self.texcoord != null, .color = self.color != null };
    }
};
