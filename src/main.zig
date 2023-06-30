// import
const std = @import("std");
const c = @import("./c.zig").c;
const gl = @import("./gl.zig");
const Window = @import("./window.zig").Window;
const Shader = @import("./Shader.zig");
const Shape = @import("./Shape.zig");
const stamp = @import("./stamp.zig");
const Slider = @import("./Slider.zig");
const state_mod = @import("./state.zig");
const color = @import("color.zig");

// alias
const info = std.debug.print;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const State = state_mod.State;
const Layer = state_mod.Layer;
const LayerList = state_mod.LayerList;
const MarkList = state_mod.MarkList;
const Cursor = state_mod.Cursor;
const RGBColor = color.RGBColor;
const HSLColor = color.HSLColor;
const Stamp = stamp.Stamp;

var cell_shader_source = @embedFile("./shader/cell.glsl");
var cell_shader: Shader = undefined;
var fixed_shader_source = @embedFile("./shader/fixed.glsl");
var fixed_shader: Shader = undefined;

const Win = Window(State);

/// onLoad runs after window and opengl have been succefully initialized
pub fn onLoad(win: *Win, state: *State) !Win.Action {
    _ = win;
    cell_shader = try Shader.init(state.allocator, "cell", cell_shader_source);
    fixed_shader = try Shader.init(state.allocator, "fixed", fixed_shader_source);
    stamp.initializeShapes();
    return .Continue;
}

pub fn drawCanvasBackground(win: *Win, state: *State) void {
    const canvas_width: f32 = @intToFloat(f32, state.canvas_width);
    const canvas_height: f32 = @intToFloat(f32, state.canvas_height);
    cell_shader.bind();
    cell_shader.setUniformVec2("window_size", @intToFloat(f32, win.window_size.width), @intToFloat(f32, win.window_size.height));
    cell_shader.setUniformVec2("canvas_size", @intToFloat(f32, state.canvas_width), @intToFloat(f32, state.canvas_width));
    cell_shader.setUniformVec4("cell_spec", 0, 0, canvas_width, canvas_height);
    cell_shader.setUniformVec3("fg_color", 0.7, 0.7, 0.7);
    stamp.rectangle.render();
}

pub fn drawLayerList(win: *Win, state: *State) void {
    for (state.layer_list.items) |layer| {
        if (layer.is_visible) {
            for (layer.mark_list.items) |mark| {
                const mark_width = @intToFloat(f32, state.canvas_width) / @intToFloat(f32, layer.width);
                const mark_height = @intToFloat(f32, state.canvas_height) / @intToFloat(f32, layer.height);
                const mark_x = @intToFloat(f32, mark.x);
                const mark_y = @intToFloat(f32, mark.y);
                cell_shader.bind();
                cell_shader.setUniformVec2("window_size", @intToFloat(f32, win.window_size.width), @intToFloat(f32, win.window_size.height));
                cell_shader.setUniformVec2("canvas_size", @intToFloat(f32, state.canvas_width), @intToFloat(f32, state.canvas_height));
                cell_shader.setUniformVec4("cell_spec", mark_x, mark_y, mark_width, mark_height);
                cell_shader.setUniformVec3("fg_color", mark.color.red, mark.color.green, mark.color.blue);
                mark.stamp.draw();
            }
        }
    }
}

pub fn drawCursor(win: *Win, state: *State) void {
    const current_layer = &state.layer_list.items[state.layer_index];
    const cursor_width = @intToFloat(f32, state.canvas_width) / @intToFloat(f32, current_layer.width);
    const cursor_height = @intToFloat(f32, state.canvas_height) / @intToFloat(f32, current_layer.height);
    const cursor_x = @intToFloat(f32, state.cursor.x);
    const cursor_y = @intToFloat(f32, state.cursor.y);
    cell_shader.bind();
    cell_shader.setUniformVec2("window_size", @intToFloat(f32, win.window_size.width), @intToFloat(f32, win.window_size.height));
    cell_shader.setUniformVec2("canvas_size", @intToFloat(f32, state.canvas_width), @intToFloat(f32, state.canvas_height));
    cell_shader.setUniformVec4("cell_spec", cursor_x, cursor_y, cursor_width, cursor_height);
    cell_shader.setUniformVec3("fg_color", 1.0, 0.141, 0.278);
    state.current_stamp.draw();
}

pub fn drawHud(win: *Win, state: *State) void {
    // draw hsl
    const prev_hsl = state.color.toHSLColor();
    state.color_hue_slider.value = prev_hsl.hue;
    state.color_light_slider.value = prev_hsl.light;
    state.color_saturation_slider.value = prev_hsl.saturation;
    state.color_hue_slider.updateAndRender(win.window_size, win.mouse_state, &fixed_shader);
    state.color_light_slider.updateAndRender(win.window_size, win.mouse_state, &fixed_shader);
    state.color_saturation_slider.updateAndRender(win.window_size, win.mouse_state, &fixed_shader);

    // update hsl
    state.color = (HSLColor{
        .hue = state.color_hue_slider.value,
        .light = state.color_light_slider.value,
        .saturation = state.color_saturation_slider.value,
    }).toRGBColor();

    // draw rgb
    state.color_red_slider.value = state.color.red;
    state.color_green_slider.value = state.color.green;
    state.color_blue_slider.value = state.color.blue;
    state.color_red_slider.updateAndRender(win.window_size, win.mouse_state, &fixed_shader);
    state.color_green_slider.updateAndRender(win.window_size, win.mouse_state, &fixed_shader);
    state.color_blue_slider.updateAndRender(win.window_size, win.mouse_state, &fixed_shader);

    // update rgb
    state.color.red = state.color_red_slider.value;
    state.color.green = state.color_green_slider.value;
    state.color.blue = state.color_blue_slider.value;

    // draw selected stamp with selected color
    fixed_shader.bind();
    fixed_shader.setUniformVec2("window_size", @intToFloat(f32, win.window_size.width), @intToFloat(f32, win.window_size.height));
    fixed_shader.setUniformVec4("dimention", @intToFloat(f32, win.window_size.width - 120), @intToFloat(f32, win.window_size.height - 120), 100, 100);
    fixed_shader.setUniformVec3("fg_color", state.color.red, state.color.green, state.color.blue);
    state.current_stamp.draw();
}

pub fn updateSnakeMode(win: *Win, state: *State) !void {
    if (state.isSnakeMode()) {
        if (@mod(win.frame, 40) == 0) {
            if (state.cursor.direction) |direction| {
                state.cursor.move(&state.layer_list.items[state.layer_index], direction);
                try state.markUpdate();
            }
        }
    }
}

// onDraw happens once per frame after onKey
pub fn onDraw(win: *Win, state: *State) !void {
    try updateSnakeMode(win, state);
    drawCanvasBackground(win, state);
    drawLayerList(win, state);
    if (state.show_cursor) {
        drawCursor(win, state);
    }
    if (state.show_hud) {
        drawHud(win, state);
    }
}

// onKey happens once per frame when before onDraw
pub fn onKey(win: *Win, state: *State, key: Win.Key) !Win.Action {
    _ = win;
    if (key == .Q) {
        info("byebye\n", .{});
        return .Quit;
    }

    if (state.mode_on_key == .SelectMode) {
        state.mode_on_key = .Normal;
        switch (key) {
            .Escape => {
                state.mode_program = .Normal;
            },
            .Space => {
                try state.markInsert();
                state.mode_program = .Insert;
            },
            .Backspace => {
                try state.markRemove();
                state.mode_program = .Remove;
            },
            .C => {
                state.show_cursor = !state.show_cursor;
            },
            .H => {
                state.show_hud = !state.show_hud;
            },
            .V => {
                state.layerIsVisibleToggle();
            },
            .S => state.snakeModeToggle(),
            else => {},
        }
        return .Continue;
    }

    try switch (key) {
        .U => state.cursorMove(.Up),
        .Comma => state.cursorMove(.Down),
        .E => state.cursorMove(.Down),
        .N => state.cursorMove(.Left),
        .O => state.cursorMove(.Right),
        .F => state.cursorMove(.UpLeft),
        .P => state.cursorMove(.UpRight),
        .L => state.cursorMove(.DownLeft),
        .Period => state.cursorMove(.DownRight),
        .J => state.snakeModeToggle(),
        .Y => state.stampNext(),
        .K => state.layerNext(),
        .Escape => state.layerClear(),
        .Enter => {
            try state.markInsert();
            if (state.isSnakeMode()) {
                state.mode_program = switch (state.mode_program) {
                    .SnakeInsert => .SnakeNormal,
                    else => .SnakeInsert,
                };
            }
        },
        .Delete => {
            try state.markRemove();
            if (state.isSnakeMode()) {
                state.mode_program = switch (state.mode_program) {
                    .SnakeRemove => .SnakeNormal,
                    else => .SnakeRemove,
                };
            }
        },
        .T => {
            state.mode_on_key = switch (state.mode_on_key) {
                .SelectMode => .Normal,
                .Normal => .SelectMode,
            };
        },
        .Backspace => {
            state.mode_program = .Normal;
            state.mode_on_key = .Normal;
            return .Continue;
        },
        else => {},
    };
    return .Continue;
}

pub fn main() !void {
    info("all your paint are belong to triangle!\n", .{});
    var GPA = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = GPA.allocator();

    var layer_list = LayerList.init(allocator);
    try layer_list.append(Layer{
        .width = 10,
        .height = 10,
        .mark_list = MarkList.init(allocator),
    });

    try layer_list.append(Layer{
        .width = 20,
        .height = 20,
        .mark_list = MarkList.init(allocator),
    });

    try layer_list.append(Layer{
        .width = 40,
        .height = 40,
        .mark_list = MarkList.init(allocator),
    });

    try layer_list.append(Layer{
        .width = 80,
        .height = 80,
        .mark_list = MarkList.init(allocator),
    });

    var red_slider = Slider.init(.{
        .origin_x = .Right,
        .origin_y = .Bottom,
        .width = 500,
        .height = 50,
        .offset_x = 630,
        .offset_y = 70,
        .bg_color = [3]f32{ 1, 0, 0 },
    });

    var green_slider = red_slider;
    green_slider.offset_y += 60;
    green_slider.bg_color = [3]f32{ 0, 1, 0 };

    var blue_slider = green_slider;
    blue_slider.bg_color = [3]f32{ 0, 0, 1 };
    blue_slider.offset_y += 60;

    var saturation_slider = blue_slider;
    saturation_slider.bg_color = [3]f32{ 0, 0, 0 };
    saturation_slider.fg_color = [3]f32{ 1, 1, 1 };
    saturation_slider.offset_x += 510;
    saturation_slider.offset_y = 70;

    var light_slider = saturation_slider;
    light_slider.bg_color = [3]f32{ 1, 1, 1 };
    light_slider.fg_color = [3]f32{ 0, 0, 0 };
    light_slider.offset_y += 60;

    var hue_slider = light_slider;
    hue_slider.bg_color = [3]f32{ 1, 1, 0 };
    hue_slider.fg_color = [3]f32{ 0, 0, 0 };
    hue_slider.offset_y += 60;

    const init_state: State = .{
        .cursor = Cursor{
            .x = 0,
            .y = 0,
        },
        .allocator = allocator,
        .layer_list = layer_list,
        .current_stamp = Stamp.Rect,
        .layer_index = 0,
        .color = RGBColor{
            .red = 0,
            .green = 0,
            .blue = 0,
        },
        .color_red_slider = Slider.init(.{
            .origin_x = .Right,
            .origin_y = .Bottom,
            .width = 500,
            .height = 50,
            .offset_x = 630,
            .offset_y = 70,
            .bg_color = [3]f32{ 1, 0, 0 },
        }),
        .color_green_slider = green_slider,
        .color_blue_slider = blue_slider,
        .color_saturation_slider = saturation_slider,
        .color_hue_slider = hue_slider,
        .color_light_slider = light_slider,
    };

    var window = try Win.init(.{
        .width = 1160,
        .height = 1250,
        .title = "OKPT",
        .onLoad = &onLoad,
        .onDraw = &onDraw,
        .onKey = &onKey,
    }, init_state);

    defer window.deinit();
    try window.drawUntilQuit();
}
