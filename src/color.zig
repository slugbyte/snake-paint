const std = @import("std");

pub const RGBColor = struct {
    red: f32,
    green: f32,
    blue: f32,

    pub fn format(value: RGBColor, comptime _: []const u8, _: std.fmt.FormatOptions, stream: anytype) !void {
        try stream.print("RGB(r{d:.2}, g{d:.2} b{d:.2})", .{ value.red, value.green, value.blue });
    }

    pub fn toHSLColor(self: RGBColor) HSLColor {
        var result = HSLColor{
            .hue = 0.0,
            .saturation = 0.0,
            .light = 0.0,
        };
        const vmax: f32 = std.math.max(self.red, std.math.max(self.green, self.blue));
        const vmin: f32 = std.math.min(self.red, std.math.min(self.green, self.blue));
        const delta: f32 = vmax - vmin;

        result.light = (vmax + vmin) / 2.0;

        if (delta == 0.0) {
            return result;
        }

        result.saturation = blk: {
            if (result.light > 0.5) {
                break :blk delta / (2.0 - vmax - vmin);
            } else {
                break :blk delta / (vmax + vmin);
            }
        };

        if (vmax == self.red) result.hue = ((self.green - self.blue) / 6.0) / delta;
        if (vmax == self.green) result.hue = (1.0 / 3.0) + ((self.blue - self.red) / 6.0) / delta;
        if (vmax == self.blue) result.hue = (2.0 / 3.0) + ((self.red - self.green) / 6.0) / delta;
        if (result.hue < 0.0) result.hue += 1.0;
        if (result.hue > 1.0) result.hue -= 1.0;

        return result;
    }
};

pub const HSLColor = struct {
    hue: f32,
    saturation: f32,
    light: f32,

    pub fn format(value: HSLColor, comptime _: []const u8, _: std.fmt.FormatOptions, stream: anytype) !void {
        try stream.print("HSL(h{d:.2}, s{d:.2}, l{d:.2})", .{ value.hue, value.saturation, value.light });
    }

    pub fn toRGBColor(self: HSLColor) RGBColor {
        var hue: f32 = self.hue * 360.0;

        return RGBColor{
            .red = HSLColor.hueToRGBValue(0, hue, self.saturation, self.light),
            .green = HSLColor.hueToRGBValue(8, hue, self.saturation, self.light),
            .blue = HSLColor.hueToRGBValue(4, hue, self.saturation, self.light),
        };
    }

    fn hueToRGBValue(q: f32, hue: f32, sat: f32, light: f32) f32 {
        var k: f32 = @rem(q + (hue / 30.0), 12.0);
        var a: f32 = sat * std.math.min(light, 1 - light);
        return light - (a * std.math.max(-1.0, std.math.min(k - 3.0, std.math.min(9.0 - k, 1))));
    }
};
