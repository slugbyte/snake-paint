const gl = @import("./gl.zig");

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    fn init(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .w = w,
        };
    }
};

pub const Color = enum {
    black,
    white,
    space,
    ocean,
    sky,
    mist,

    fn getVec4(self: *Color) Vec4 {
        switch (self) {
            .black => Vec4.init(0, 0, 0, 1),
            .white => Vec4.init(1, 1, 1, 1),
            .space => Vec4.init(0, 0, 0.1, 1),
            .ocean => Vec4.init(0, 0, 0.3, 1),
            .sky => Vec4.init(0, 0, 0.5, 1),
            .mist => Vec4.init(0, 0, 0.9, 1),
        }
    }
};
