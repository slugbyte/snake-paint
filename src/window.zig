const std = @import("std");
const c = @import("./c.zig").c;
const gl = @import("./gl.zig");
const info = std.debug.print;

const Self = @This();
pub const GlfwWindow = ?*c.GLFWwindow;
pub const WindowError = error{
    GlfwInit,
    GlfwCreateWindow,
    GladLoadGl,
    GlCompileShader,
    GlProgramLink,
};

pub const Action = enum {
    Quit,
    Continue,
};

pub const Key = enum(c_uint) {
    M = c.GLFW_KEY_M, // mode
    A = c.GLFW_KEY_A, // angle
    C = c.GLFW_KEY_C, // color
    B = c.GLFW_KEY_B, // bg set
    X = c.GLFW_KEY_X, // clear
    S = c.GLFW_KEY_S, // save
    Q = c.GLFW_KEY_Q, // save
    Up = c.GLFW_KEY_UP, // up
    Down = c.GLFW_KEY_DOWN, // down
    Left = c.GLFW_KEY_LEFT, // left
    Right = c.GLFW_KEY_RIGHT, // right
};

fn KeyDownStateCreate() type {
    const key_fields = std.meta.fields(Key);
    comptime var key_state_field_list: [key_fields.len]std.builtin.Type.StructField = undefined;

    comptime var index: usize = 0;
    inline for (key_fields) |field| {
        key_state_field_list[index] = .{
            .name = field.name,
            .type = bool,
            .default_value = @ptrCast(*const anyopaque, &false),
            .is_comptime = false,
            .alignment = @alignOf(bool),
        };
        index += 1;
    }

    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .is_tuple = false,
            .fields = &key_state_field_list,
            .decls = &.{},
        },
    });
}

const KeyDownState = KeyDownStateCreate();

pub const Handler = struct {
    onLoad: *const fn () anyerror!Action,
    onDraw: *const fn () anyerror!void,
    onKey: *const fn (key: Key) anyerror!Action,
};

glfw_window: ?*c.GLFWwindow,
handler: Handler,
key_state: KeyDownState = .{},

pub fn init(handler: Handler) WindowError!Self {
    if (c.glfwInit() != c.GLFW_TRUE) {
        return WindowError.GlfwInit;
    }
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
    c.glfwSwapInterval(1);

    const maby_window = c.glfwCreateWindow(1000, 1000, "OKPT", null, null);
    if (maby_window == null) {
        return WindowError.GlfwCreateWindow;
    }

    const window = maby_window.?;
    c.glfwMakeContextCurrent(window);

    gl.load({}, glProcAddressGet) catch {
        return WindowError.GladLoadGl;
    };
    _ = c.glfwSetFramebufferSizeCallback(window, resizeCallback);

    return .{
        .glfw_window = maby_window,
        .handler = handler,
    };
}

pub fn deinit(self: *Self) void {
    c.glfwDestroyWindow(self.glfw_window);
}

pub fn drawUntilQuit(self: *Self) anyerror!void {
    if (try self.handler.onLoad() == .Quit) {
        info("onLoad quit program\n", .{});
        return;
    }

    while (c.glfwWindowShouldClose(self.glfw_window) != 1) {
        if (try self.handleInput() == .Quit) {
            _ = c.glfwSetWindowShouldClose(self.glfw_window, c.GLFW_TRUE);
            continue;
        }

        gl.clearColor(0, 0, 1.0, 0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        try self.handler.onDraw();

        c.glfwSwapBuffers(self.glfw_window);
        c.glfwPollEvents();
    }
}

fn handleInput(self: *Self) anyerror!Action {
    const key_field_list = std.meta.fields(Key);
    var result: Action = .Continue;
    inline for (key_field_list) |field| {
        if (c.glfwGetKey(self.glfw_window, field.value) == c.GLFW_PRESS) {
            if (!@field(self.key_state, field.name)) {
                info("[key press active] {s}\n", .{field.name});
                @field(self.key_state, field.name) = true;
                result = try self.handler.onKey(@intToEnum(Key, field.value));
            }
        }
        if (c.glfwGetKey(self.glfw_window, field.value) == c.GLFW_RELEASE) {
            if (@field(self.key_state, field.name)) {
                @field(self.key_state, field.name) = false;
            }
        }
    }
    return result;
}

fn glProcAddressGet(p: void, proc_name: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
    if (c.glfwGetProcAddress(proc_name)) |proc_address| {
        return proc_address;
    }
    return null;
}

fn resizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    gl.viewport(0, 0, width, height);
    _ = window;
}
