const Shape = @import("./Shape.zig");

pub var triangle_a: Shape = undefined;
pub var triangle_b: Shape = undefined;
pub var triangle_c: Shape = undefined;
pub var triangle_d: Shape = undefined;
pub var rectangle: Shape = undefined;

pub const Stamp = enum {
    TriA,
    TriB,
    TriC,
    TriD,
    Rect,

    pub fn draw(self: Stamp) void {
        switch (self) {
            .TriA => triangle_a.render(),
            .TriB => triangle_b.render(),
            .TriC => triangle_c.render(),
            .TriD => triangle_d.render(),
            .Rect => rectangle.render(),
        }
    }
};

pub fn initializeShapes() void {
    var vertex_data = [_]f32{
        0, 0, // top_left
        0, 1, // bottom_left
        1, 1, // bottom_right
        1, 0, // top_right
    };

    const top_left: c_uint = 0;
    const bottom_left: c_uint = 1;
    const bottom_right: c_uint = 2;
    const top_right: c_uint = 3;

    const triangle_a_index_list = [_]c_uint{
        top_left,
        top_right,
        bottom_left,
    };
    triangle_a = Shape.initWithIndexBuffer(vertex_data[0..], triangle_a_index_list[0..]);

    const triangle_b_index_list = [_]c_uint{
        top_left,
        top_right,
        bottom_right,
    };
    triangle_b = Shape.initWithIndexBuffer(vertex_data[0..], triangle_b_index_list[0..]);

    const triangle_c_index_list = [_]c_uint{
        bottom_left,
        bottom_right,
        top_right,
    };
    triangle_c = Shape.initWithIndexBuffer(vertex_data[0..], triangle_c_index_list[0..]);

    const triangle_d_index_list = [_]c_uint{
        top_left,
        bottom_left,
        bottom_right,
    };
    triangle_d = Shape.initWithIndexBuffer(vertex_data[0..], triangle_d_index_list[0..]);

    const rectangle_index_list = [_]c_uint{
        top_left,
        top_right,
        bottom_left,

        top_right,
        bottom_left,
        bottom_right,
    };
    rectangle = Shape.initWithIndexBuffer(vertex_data[0..], rectangle_index_list[0..]);
}
