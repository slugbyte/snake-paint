const std = @import("std");
const c = @import("./c.zig").c;
const gl = @import("./gl.zig");
const info = std.debug.print;

pub fn Window(comptime state: type) type {
    return struct {
        const Self = @This();
        glfw_window: ?*c.GLFWwindow,
        key_state: KeyDownState = .{},
        state: state,
        width: c_int,
        height: c_int,
        title: []const u8,
        onLoad: *const fn (window: *Self, state: *state) anyerror!Action,
        onDraw: *const fn (window: *Self, state: *state) anyerror!void,
        onKey: *const fn (window: *Self, state: *state, key: Key) anyerror!Action,

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
            L = c.GLFW_KEY_L, // bg set
            X = c.GLFW_KEY_X, // clear
            S = c.GLFW_KEY_S, // save
            Q = c.GLFW_KEY_Q, // save
            V = c.GLFW_KEY_V, // save
            W = c.GLFW_KEY_W, // place mark
            Up = c.GLFW_KEY_E, // up
            Down = c.GLFW_KEY_N, // down
            Left = c.GLFW_KEY_Y, // left
            Right = c.GLFW_KEY_O, // right
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

        pub const Config = struct {
            width: c_int,
            height: c_int,
            title: []const u8,
            onLoad: *const fn (
                window: *Self,
                state: *state,
            ) anyerror!Action,
            onDraw: *const fn (window: *Self, state: *state) anyerror!void,
            onKey: *const fn (window: *Self, state: *state, key: Key) anyerror!Action,
        };

        pub fn init(config: Config, init_state: state) WindowError!Self {
            if (c.glfwInit() != c.GLFW_TRUE) {
                return WindowError.GlfwInit;
            }
            c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
            c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
            c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
            c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
            c.glfwSwapInterval(1);

            const maby_glfw_window = c.glfwCreateWindow(config.width, config.height, config.title.ptr, null, null);
            if (maby_glfw_window == null) {
                return WindowError.GlfwCreateWindow;
            }

            const glfw_window = maby_glfw_window.?;
            c.glfwMakeContextCurrent(glfw_window);

            gl.load({}, glProcAddressGet) catch {
                return WindowError.GladLoadGl;
            };
            _ = c.glfwSetFramebufferSizeCallback(glfw_window, resizeCallback);

            return .{
                .state = init_state,
                .title = config.title,
                .width = config.width,
                .height = config.height,
                .onKey = config.onKey,
                .onLoad = config.onLoad,
                .onDraw = config.onDraw,
                .glfw_window = maby_glfw_window,
            };
        }

        pub fn deinit(self: *Self) void {
            c.glfwDestroyWindow(self.glfw_window);
        }

        pub fn drawUntilQuit(self: *Self) anyerror!void {
            if (try self.onLoad(self, &self.state) == .Quit) {
                info("onLoad quit program\n", .{});
                return;
            }

            while (c.glfwWindowShouldClose(self.glfw_window) != 1) {
                self.preDrawWindowUpdate();
                if (try self.handleInput() == .Quit) {
                    _ = c.glfwSetWindowShouldClose(self.glfw_window, c.GLFW_TRUE);
                    continue;
                }

                gl.clearColor(0, 0, 1.0, 0);
                gl.clear(gl.COLOR_BUFFER_BIT);

                try self.onDraw(self, &self.state);

                c.glfwSwapBuffers(self.glfw_window);
                c.glfwPollEvents();
            }
        }

        fn preDrawWindowUpdate(self: *Self) void {
            c.glfwGetWindowSize(self.glfw_window, &self.width, &self.height);
            // TODO set mouse_x, mouse_y
        }

        fn handleInput(self: *Self) anyerror!Action {
            const key_field_list = std.meta.fields(Key);
            var result: Action = .Continue;
            inline for (key_field_list) |field| {
                if (c.glfwGetKey(self.glfw_window, field.value) == c.GLFW_PRESS) {
                    if (!@field(self.key_state, field.name)) {
                        info("[key press active] {s}\n", .{field.name});
                        @field(self.key_state, field.name) = true;
                        result = try self.onKey(self, &self.state, @intToEnum(Key, field.value));
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
    };
}
