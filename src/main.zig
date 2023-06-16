const std = @import("std");
const info = std.debug.print;
const c = @import("./c.zig").c;
const gl = @import("./gl.zig");

const Err = error{
    GlfwInit,
    GlfwCreateWindow,
    GladLoadGl,
    GlCompileShader,
    GlProgramLink,
};

pub fn main() !void {
    if (c.glfwInit() != c.GLFW_TRUE) {
        return Err.GlfwInit;
    }
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
    c.glfwSwapInterval(1);

    const maby_window = c.glfwCreateWindow(1000, 1000, "OKPT", null, null);
    if (maby_window == null) {
        return Err.GlfwCreateWindow;
    }

    const window = maby_window.?;
    c.glfwMakeContextCurrent(window);

    gl.load({}, windowGlProcAddressGet) catch {
        return Err.GladLoadGl;
    };
    _ = c.glfwSetFramebufferSizeCallback(window, windowResizeCallback);
    info("all your paint are belong to triangle!\n\n", .{});
    info("press q to quit\n", .{});
    while (c.glfwWindowShouldClose(window) != 1) {
        if (c.glfwGetKey(window, c.GLFW_KEY_Q) == c.GLFW_PRESS) {
            info("byebye!\n", .{});
            _ = c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
        }

        gl.clearColor(0, 0, 1.0, 0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}

pub fn windowGlProcAddressGet(p: void, proc_name: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
    if (c.glfwGetProcAddress(proc_name)) |proc_address| {
        return proc_address;
    }
    return null;
}

pub fn windowResizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    // info("window size w:{d} h:{d}\n", .{ width, height });
    gl.viewport(0, 0, width, height);
    _ = window;
}
