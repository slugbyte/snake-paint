// import
const std = @import("std");
const c = @import("./c.zig").c;
const gl = @import("./gl.zig");
const Window = @import("./window.zig").Window;
const Shader = @import("./Shader.zig");
const Shape = @import("./Shape.zig");
const stamp = @import("./stamp.zig");
const Slider = @import("./Slider.zig");
const color = @import("color.zig");

// alias
const info = std.debug.print;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const RGBColor = color.RGBColor;
const HSLColor = color.HSLColor;
const Stamp = stamp.Stamp;

pub const Mark = struct {
    color: RGBColor,
    stamp: Stamp,
    x: i32,
    y: i32,
};

pub const MarkList = ArrayList(Mark);

pub const Layer = struct {
    width: i32,
    height: i32,
    mark_list: MarkList,
};

pub const LayerList = ArrayList(Layer);

pub const Cursor = struct {
    x: i32,
    y: i32,

    pub const Direction = enum {
        Up,
        Down,
        Left,
        Right,
    };

    pub fn move(self: *Cursor, layer: *const Layer, direction: Direction) void {
        switch (direction) {
            .Up => {
                if (self.y > 0) {
                    self.y -= 1;
                }
            },
            .Left => {
                if (self.x > 0) {
                    self.x -= 1;
                }
            },
            .Down => {
                self.y = std.math.clamp(self.y + 1, 0, layer.height - 1);
            },
            .Right => {
                self.x = std.math.clamp(self.x + 1, 0, layer.width - 1);
            },
        }
    }
};

pub const State = struct {
    canvas_width: u32 = 1000,
    canvas_height: u32 = 1000,

    layer_list: LayerList,
    layer_index: u32,

    cursor: Cursor,
    current_stamp: Stamp,

    is_togle_mode: bool = false,
    show_cursor: bool = true,
    show_hud: bool = true,

    color: RGBColor,
    color_red_slider: Slider,
    color_green_slider: Slider,
    color_blue_slider: Slider,
    color_hue_slider: Slider,
    color_light_slider: Slider,
    color_saturation_slider: Slider,
    allocator: Allocator,

    pub fn layerNext(self: *State) void {
        const prev_layer = &self.layer_list.items[self.layer_index];
        const prev_cursor_width = @divFloor(@intCast(i32, self.canvas_width), prev_layer.width);
        const prev_cursor_height = @divFloor(@intCast(i32, self.canvas_height), prev_layer.height);
        const cursor_x_in_px = self.cursor.x * prev_cursor_width;
        const cursor_y_in_px = self.cursor.y * prev_cursor_height;

        // update current layer index to next layer
        self.layer_index = @mod(self.layer_index + 1, @intCast(u32, self.layer_list.items.len));
        const next_layer: *Layer = &self.layer_list.items[self.layer_index];

        const cursor_width = @divFloor(@intCast(i32, self.canvas_width), next_layer.width);
        const cursor_height = @divFloor(@intCast(i32, self.canvas_height), next_layer.height);

        self.cursor.x = std.math.clamp(@divFloor(cursor_x_in_px, cursor_width), 0, next_layer.width - 1);
        self.cursor.y = std.math.clamp(@divFloor(cursor_y_in_px, cursor_height), 0, next_layer.height - 1);
    }

    pub fn stampNext(self: *State) void {
        self.current_stamp = switch (self.current_stamp) {
            .Rect => .TriA,
            .TriA => .TriB,
            .TriB => .TriC,
            .TriC => .TriD,
            .TriD => .Rect,
        };
    }

    pub fn markInsert(self: *State) !void {
        const current_layer = &self.layer_list.items[self.layer_index];
        try current_layer.mark_list.append(Mark{
            .x = self.cursor.x,
            .y = self.cursor.y,
            .stamp = self.current_stamp,
            .color = RGBColor{
                .red = self.color.red,
                .green = self.color.green,
                .blue = self.color.blue,
            },
        });
    }

    pub fn markRemove(self: *State) !void {
        var current_layer = &self.layer_list.items[self.layer_index];
        var mark_list: *MarkList = &current_layer.mark_list;

        var index: usize = 0;
        while (index < mark_list.items.len) : (index += 1) {
            const mark = mark_list.items[index];
            if (mark.x == self.cursor.x and mark.y == self.cursor.y) {
                _ = mark_list.orderedRemove(index);
                if (index > 0) {
                    index -= 1;
                }
            }
        }

        if (mark_list.items.len == 1) {
            if (mark_list.items[0].x == self.cursor.x and mark_list.items[0].y == self.cursor.y) {
                _ = mark_list.swapRemove(0);
            }
        }
    }
};
