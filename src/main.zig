// import
const std = @import("std");
const zlm = @import("zlm");
const c = @import("./c.zig").c;
const gl = @import("./gl.zig");
const Window = @import("./window.zig").Window;
const Shader = @import("./Shader.zig");
const Shape = @import("./Shape.zig");

// alias
const info = std.debug.print;
const Allocator = std.mem.Allocator;

// type
const Color = enum {
    Black,
    White,
    BlueA,
    BlueB,
    BlueC,
    BlueD,
};

const Stamp = enum {
    TriA,
    TriB,
    TriC,
    TriD,
    Rect,
};

const Layer = enum {
    Background,
    Foreground,
};

const Mode = enum {
    Insert,
    Visual,
};

const Mark = struct {
    color: Color,
    stamp: Stamp,
};

const Direction = enum {
    Up,
    Down,
    Left,
    Right,
};

const Action = union(enum) {
    NextStamp,
    NextColor,
    PaintStamp,
    PaintBackground,
    Move: Direction,
    Undo,
    Redo,
};

const State = struct {
    layer_bg_width: u32,
    layer_bg_height: u32,
    layer_bg_data: []?Mark,
    layer_fg_width: u32,
    layer_fg_height: u32,
    layer_fg_data: []?Mark,
    cursor_x: u32,
    cursor_y: u32,
    current_stamp: Stamp,
    current_color: Color,
    current_layer: Layer,
};

var alley: Allocator = undefined;
var cell_shader_source = @embedFile("./shader/cell.glsl");
var cell_shader: Shader = undefined;

var triangle_a: Shape = undefined;
var triangle_b: Shape = undefined;
var triangle_c: Shape = undefined;
var triangle_d: Shape = undefined;
var rectangle: Shape = undefined;

const Win = Window(State);

pub fn onLoad(win: *Win, state: *State) !Win.Action {
    _ = win;
    _ = state;
    info("onLoad!\n", .{});
    cell_shader = try Shader.init(alley, "cell", cell_shader_source);
    initizeShapes();
    return .Continue;
}

pub fn renderStamp(stamp: Stamp) void {
    switch (stamp) {
        .TriA => triangle_a.render(),
        .TriB => triangle_b.render(),
        .TriC => triangle_c.render(),
        .TriD => triangle_d.render(),
        .Rect => rectangle.render(),
    }
}

pub fn drawBackground(win: *Win, state: *State) void {
    for (state.layer_bg_data, 0..) |maby_mark, offset| {
        if (maby_mark) |mark| {
            const cell_y: f32 = @intToFloat(f32, offset / state.layer_bg_width);
            const cell_x: f32 = @intToFloat(f32, offset - (state.layer_bg_width * @floatToInt(u32, cell_y)));
            cell_shader.bind();
            cell_shader.setUniformVec2("window_size", @intToFloat(f32, win.width), @intToFloat(f32, win.height));
            cell_shader.setUniformVec4("cell_spec", cell_x, cell_y, 100, 100);

            switch (mark.color) {
                .White => cell_shader.setUniformVec3("fg_color", 1.0, 1.0, 1.0),
                .Black => cell_shader.setUniformVec3("fg_color", 0.0, 0.0, 0.0),
                .BlueA => cell_shader.setUniformVec3("fg_color", 0.0, 0.141, 0.278),
                .BlueB => cell_shader.setUniformVec3("fg_color", 0.086, 0.219, 0.347),
                .BlueC => cell_shader.setUniformVec3("fg_color", 0.207, 0.367, 0.515),
                .BlueD => cell_shader.setUniformVec3("fg_color", 0.381, 0.593, 0.796),
            }

            renderStamp(mark.stamp);
        }
    }
}

pub fn drawForeground(win: *Win, state: *State) void {
    for (state.layer_fg_data, 0..) |maby_mark, offset| {
        if (maby_mark) |mark| {
            const cell_y: f32 = @intToFloat(f32, offset / state.layer_fg_width);
            const cell_x: f32 = @intToFloat(f32, offset - (state.layer_fg_width * @floatToInt(u32, cell_y)));
            cell_shader.bind();
            cell_shader.setUniformVec2("window_size", @intToFloat(f32, win.width), @intToFloat(f32, win.height));
            cell_shader.setUniformVec4("cell_spec", cell_x, cell_y, 50, 50);

            switch (mark.color) {
                .White => cell_shader.setUniformVec3("fg_color", 1.0, 1.0, 1.0),
                .Black => cell_shader.setUniformVec3("fg_color", 0.0, 0.0, 0.0),
                .BlueA => cell_shader.setUniformVec3("fg_color", 0.0, 0.141, 0.278),
                .BlueB => cell_shader.setUniformVec3("fg_color", 0.086, 0.219, 0.347),
                .BlueC => cell_shader.setUniformVec3("fg_color", 0.207, 0.367, 0.515),
                .BlueD => cell_shader.setUniformVec3("fg_color", 0.381, 0.593, 0.796),
            }

            renderStamp(mark.stamp);
        }
    }
}

pub fn drawCursor(win: *Win, state: *State) void {
    switch (state.current_layer) {
        .Background => {
            const cell_y: f32 = @intToFloat(f32, state.cursor_y);
            const cell_x: f32 = @intToFloat(f32, state.cursor_x);
            cell_shader.bind();
            cell_shader.setUniformVec2("window_size", @intToFloat(f32, win.width), @intToFloat(f32, win.height));
            cell_shader.setUniformVec4("cell_spec", cell_x, cell_y, 100, 100);
            cell_shader.setUniformVec3("fg_color", 1.0, 0.141, 0.278);
            renderStamp(state.current_stamp);
        },
        .Foreground => {
            const cell_y: f32 = @intToFloat(f32, state.cursor_y);
            const cell_x: f32 = @intToFloat(f32, state.cursor_x);
            cell_shader.bind();
            cell_shader.setUniformVec2("window_size", @intToFloat(f32, win.width), @intToFloat(f32, win.height));
            cell_shader.setUniformVec4("cell_spec", cell_x, cell_y, 50, 50);
            cell_shader.setUniformVec3("fg_color", 1.0, 0.141, 0.278);
            renderStamp(state.current_stamp);
        },
    }
}

pub fn onDraw(win: *Win, state: *State) !void {
    // _ = win;
    // _ = state;
    // info("{any}\n", .{state.*});
    gl.clearColor(0.91, 0.51, 0.91, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    drawBackground(win, state);
    drawForeground(win, state);
    drawCursor(win, state);
    // cell_shader.setUniformMat4("projection", orth);
}

pub fn onKey(win: *Win, state: *State, key: Win.Key) !Win.Action {
    _ = win;
    return switch (key) {
        .Right => {
            state.cursor_x += 1;
            return .Continue;
        },
        .Left => {
            if (state.cursor_x > 0) {
                state.cursor_x -= 1;
            }
            return .Continue;
        },
        .Up => {
            if (state.cursor_y > 0) {
                state.cursor_y -= 1;
            }
            return .Continue;
        },
        .Down => {
            state.cursor_y += 1;
            return .Continue;
        },
        .L => {
            state.current_layer = switch (state.current_layer) {
                .Background => .Foreground,
                .Foreground => .Background,
            };
            info("seleced layer {any}\n", .{state.current_layer});
            return .Continue;
        },
        .W => {
            info("time to mark\n", .{});
            switch (state.current_layer) {
                .Background => {
                    const offset: usize = (state.cursor_y * state.layer_bg_width) + state.cursor_x;
                    state.layer_bg_data[offset] = .{
                        .color = state.current_color,
                        .stamp = state.current_stamp,
                    };
                    info("{d},{d} is now {any}\n ", .{ state.cursor_x, state.cursor_y, state.current_stamp });
                    return .Continue;
                },
                .Foreground => {
                    const offset: usize = (state.cursor_y * state.layer_fg_width) + state.cursor_x;
                    state.layer_fg_data[offset] = .{
                        .color = state.current_color,
                        .stamp = state.current_stamp,
                    };
                    info("{d},{d} is now {any}\n ", .{ state.cursor_x, state.cursor_y, state.current_stamp });
                    return .Continue;
                },
            }
        },
        .X => {
            const offset: usize = (state.cursor_y * state.layer_bg_width) + state.cursor_x;
            state.layer_bg_data[offset] = null;
            return .Continue;
        },
        .C => {
            state.current_color = switch (state.current_color) {
                .Black => .White,
                .White => .BlueA,
                .BlueA => .BlueB,
                .BlueB => .BlueC,
                .BlueC => .BlueD,
                .BlueD => .Black,
            };
            info("selected color: {any}\n", .{state.current_color});
            return .Continue;
        },
        .S => {
            state.current_stamp = switch (state.current_stamp) {
                .Rect => .TriA,
                .TriA => .TriB,
                .TriB => .TriC,
                .TriC => .TriD,
                .TriD => .Rect,
            };
            info("selected stamp: {any}\n", .{state.current_stamp});
            return .Continue;
        },
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

    const wat = zlm.vec2(0.1, 1.0);
    info("wat: {any}\n", .{wat});

    var layer_bg_data = [1]?Mark{null} ** 100;

    layer_bg_data[23] = .{
        .stamp = .Rect,
        .color = .White,
    };
    var layer_fg_data = [1]?Mark{null} ** (20 * 20);

    const init_state: State = .{
        .cursor_x = 0,
        .cursor_y = 0,
        .layer_bg_width = 10,
        .layer_bg_height = 10,
        .layer_bg_data = layer_bg_data[0..],
        .layer_fg_width = 20,
        .layer_fg_height = 20,
        .layer_fg_data = layer_fg_data[0..],
        .current_stamp = Stamp.Rect,
        .current_color = Color.White,
        .current_layer = Layer.Foreground,
    };

    var window = try Win.init(.{
        .width = 1000,
        .height = 1000 - 74,
        .title = "OKPT",
        .onLoad = &onLoad,
        .onDraw = &onDraw,
        .onKey = &onKey,
    }, init_state);
    defer window.deinit();
    try window.drawUntilQuit();
}

fn initizeShapes() void {
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
