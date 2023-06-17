const std = @import("std");
const info = std.debug.print;
const c = @import("./c.zig").c;
const gl = @import("./gl.zig");
const Window = @import("./window.zig");
const Allocator = std.mem.Allocator;
const Shader = @import("./Shader.zig");

const Color = enum {
    Black,
    White,
    BlueA,
    BlueB,
    BlueC,
    BlueD,
};

const GlShape = struct {
    vao: c_uint,
    ebo: c_uint,
    vbo: c_uint,
};

const Shape = enum {
    TriA,
    TriB,
    TriC,
    TriD,
    Rect,
};

const Mode = enum {
    Insert,
    Visual,
};

const Mark = struct {
    color: Color,
    shape: Shape,
};

const Direction = enum {
    Up,
    Down,
    Left,
    Right,
};

const Action = union(enum) {
    NextShape,
    NextColor,
    PaintShape,
    PaintBackground,
    Move: Direction,
    Undo,
    Redo,
};

const State = struct {
    width: u32,
    height: u32,
    mark_list: []Mark,
    current_shape: Shape,
    current_color: Color,
};

var alley: Allocator = undefined;
var blue_shader_source = @embedFile("./shader/blue.glsl");
var blue_shader: Shader = undefined;
var test_vao_id: c_uint = undefined;
var test_vbo_id: c_uint = undefined;
var test_vertex_list = [_]f32{
    -0.5, 0.5,
    -0.5, -0.5,
    0.5,  -0.5,
};

pub fn onLoad() !Window.Action {
    info("onLoad!\n", .{});
    blue_shader = try Shader.init(alley, "blue", blue_shader_source);

    gl.genVertexArrays(1, &test_vao_id);
    gl.genBuffers(1, &test_vbo_id);

    gl.bindVertexArray(test_vao_id);
    gl.bindBuffer(gl.ARRAY_BUFFER, test_vbo_id);
    gl.bufferData(gl.ARRAY_BUFFER, 6 * @sizeOf(f32), &test_vertex_list, gl.STATIC_DRAW);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), @intToPtr(?*const anyopaque, 0));
    gl.enableVertexAttribArray(0);

    return .Continue;
}

pub fn onDraw() !void {
    gl.clearColor(1, 0, 0, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    blue_shader.bind();
    gl.bindVertexArray(test_vao_id);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
}

pub fn onKey(key: Window.Key) !Window.Action {
    return switch (key) {
        .Q => {
            info("byebye!\n", .{});
            return .Quit;
        },
        else => .Continue,
    };
}

pub fn main() !void {
    info("all your paint are belong to triangle!\n", .{});
    var GPA = std.heap.GeneralPurposeAllocator(.{}){};
    alley = GPA.allocator();

    var window = try Window.init(.{
        .onLoad = &onLoad,
        .onDraw = &onDraw,
        .onKey = &onKey,
    });
    defer window.deinit();

    try window.drawUntilQuit();
}
