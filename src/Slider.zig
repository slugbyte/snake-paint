const std = @import("std");
const WindowSize = @import("./window.zig").WindowSize;
const MouseState = @import("./window.zig").MouseState;
const Shader = @import("./Shader.zig");
const Shape = @import("./Shape.zig");
const Stamp = @import("./stamp.zig").Stamp;

const clamp = std.math.clamp;
const info = std.debug.print;

const Self = @This();
orientation: Orientation = .Horizontal,
origin_x: OriginX,
origin_y: OriginY,
offset_x: i32,
offset_y: i32,
width: i32,
height: i32,
border_size: i32,
is_hover: bool = false,
is_active: bool = false,
value: f32 = 0,
bg_color: [3]f32,
fg_color: [3]f32,
// TODO add bg_color and fg_color

const Orientation = enum {
    Vertical,
    Horizontal,
};

const OriginY = enum {
    Bottom,
    Top,
};

const OriginX = enum {
    Left,
    Right,
};

pub const Config = struct {
    width: i32,
    height: i32,
    border_size: i32 = 10,
    origin_x: OriginX = .Left,
    origin_y: OriginY = .Top,
    offset_x: i32 = 0,
    offset_y: i32 = 0,
    fg_color: [3]f32 = [3]f32{ 0, 0, 0 },
    bg_color: [3]f32 = [3]f32{ 1, 1, 1 },
};

pub fn getOriginXPixel(self: Self, window_size: WindowSize) i32 {
    if (self.origin_x == .Left) {
        return 0;
    }
    return window_size.width;
}

pub fn getOriginYPixel(self: Self, window_size: WindowSize) i32 {
    if (self.origin_y == .Top) {
        return 0;
    }
    return window_size.height;
}

pub fn init(config: Config) Self {
    return .{
        .value = 0,
        .origin_x = config.origin_x,
        .origin_y = config.origin_y,
        .offset_x = config.offset_x,
        .offset_y = config.offset_y,
        .width = config.width,
        .height = config.height,
        .border_size = config.border_size,
        .bg_color = config.bg_color,
        .fg_color = config.fg_color,
    };
}

pub fn updateAndRender(self: *Self, window_size: WindowSize, mouse_state: MouseState, shader: *Shader) void {
    // TODO switch to variable bar_height when .Vertical
    const container_x = self.getOriginXPixel(window_size) + switch (self.origin_x) {
        .Left => self.offset_x,
        .Right => -1 * self.offset_x,
    };
    const container_y = self.getOriginYPixel(window_size) + switch (self.origin_y) {
        .Top => self.offset_y,
        .Bottom => -1 * self.offset_y,
    };
    const bar_x = container_x + self.border_size;
    const bar_y = container_y + self.border_size;
    const bar_height = self.height - (self.border_size * 2);
    var bar_width = self.width - (self.border_size * 2);

    self.is_hover = check_hover: {
        const is_x_in_range = mouse_state.x > container_x and mouse_state.x < (container_x + self.width);
        const is_y_in_range = mouse_state.y > container_y and mouse_state.y < (container_y + self.height);
        break :check_hover is_x_in_range and is_y_in_range;
    };

    if (self.is_hover and mouse_state.button_left_active) {
        self.is_active = true;
        const mouse_x_local = std.math.clamp(mouse_state.x - bar_x, 0, bar_width);

        self.value = clamp(@intToFloat(f32, mouse_x_local) / @intToFloat(f32, bar_width), 0, 1.0);
    } else {
        self.is_active = false;
    }

    bar_width = @floatToInt(i32, @intToFloat(f32, bar_width) * self.value);

    // draw container
    shader.bind();
    shader.setUniformVec2("window_size", @intToFloat(f32, window_size.width), @intToFloat(f32, window_size.height));
    shader.setUniformVec4("dimention", @intToFloat(f32, container_x), @intToFloat(f32, container_y), @intToFloat(f32, self.width), @intToFloat(f32, self.height));
    shader.setUniformVec3("fg_color", self.bg_color[0], self.bg_color[1], self.bg_color[2]);
    Stamp.Rect.draw();

    // draw bar
    shader.bind();
    shader.setUniformVec2("window_size", @intToFloat(f32, window_size.width), @intToFloat(f32, window_size.height));
    shader.setUniformVec4("dimention", @intToFloat(f32, bar_x), @intToFloat(f32, bar_y), @intToFloat(f32, bar_width), @intToFloat(f32, bar_height));
    shader.setUniformVec3("fg_color", self.fg_color[0], self.fg_color[1], self.fg_color[2]);
    Stamp.Rect.draw();
}
