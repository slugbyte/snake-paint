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
    cell_shader.setUniformVec3("fg_color", 1, 1, 1);
    stamp.rectangle.render();
}

pub fn drawLayerList(win: *Win, state: *State) void {
    for (state.layer_list.items) |layer| {
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

// onDraw happens once per frame after onKey
pub fn onDraw(win: *Win, state: *State) !void {
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
    return switch (key) {
        .O => {
            const current_layer = &state.layer_list.items[state.layer_index];
            state.cursor.move(current_layer, .Right);
            return .Continue;
        },
        .Y => {
            const current_layer = &state.layer_list.items[state.layer_index];
            state.cursor.move(current_layer, .Left);
            return .Continue;
        },
        .E => {
            const current_layer = &state.layer_list.items[state.layer_index];
            state.cursor.move(current_layer, .Up);
            return .Continue;
        },
        .N => {
            const current_layer = &state.layer_list.items[state.layer_index];
            state.cursor.move(current_layer, .Down);
            return .Continue;
        },
        .L => {
            state.layerNext();
            return .Continue;
        },
        .T => {
            state.is_togle_mode = true;
            return .Continue;
        },
        .Escape => {
            state.is_togle_mode = false;
            return .Continue;
        },
        .C => {
            if (state.is_togle_mode) {
                state.show_cursor = !state.show_cursor;
                state.is_togle_mode = false;
            }
            return .Continue;
        },
        .H => {
            if (state.is_togle_mode) {
                state.show_hud = !state.show_hud;
                state.is_togle_mode = false;
            }
            return .Continue;
        },
        .Space => {
            try state.markInsert();
            return .Continue;
        },
        .Backspace => {
            try state.markRemove();
            return .Continue;
        },
        .S => {
            state.stampNext();
            return .Continue;
        },
        .Q => {
            info("byebye!\n", .{});
            return .Quit;
        },
        else => {
            return .Continue;
        },
    };
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
