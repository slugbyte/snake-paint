const std = @import("std");
const c = @import("./c.zig").c;
const gl = @import("./gl.zig");
const info = std.debug.print;

pub const MouseState = struct {
    x: i32 = -1,
    y: i32 = -1,
    button_left_active: bool = false,
    button_right_active: bool = false,
};

pub const WindowSize = struct {
    width: i32,
    height: i32,
};

pub fn Window(comptime state: type) type {
    return struct {
        const Self = @This();
        glfw_window: ?*c.GLFWwindow,
        key_state: KeyDownState = .{},
        state: state,
        mouse_state: MouseState,
        window_size: WindowSize,
        title: []const u8,
        delta_time: f32 = 0,
        frame: u32 = 0,
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
            A = c.GLFW_KEY_A,
            B = c.GLFW_KEY_B,
            C = c.GLFW_KEY_C,
            D = c.GLFW_KEY_D,
            E = c.GLFW_KEY_E,
            F = c.GLFW_KEY_F,
            G = c.GLFW_KEY_G,
            H = c.GLFW_KEY_H,
            I = c.GLFW_KEY_I,
            J = c.GLFW_KEY_J,
            K = c.GLFW_KEY_K,
            L = c.GLFW_KEY_L,
            M = c.GLFW_KEY_M,
            N = c.GLFW_KEY_N,
            O = c.GLFW_KEY_O,
            P = c.GLFW_KEY_P,
            Q = c.GLFW_KEY_Q,
            R = c.GLFW_KEY_R,
            S = c.GLFW_KEY_S,
            T = c.GLFW_KEY_T,
            U = c.GLFW_KEY_U,
            V = c.GLFW_KEY_V,
            W = c.GLFW_KEY_W,
            X = c.GLFW_KEY_X,
            Y = c.GLFW_KEY_Y,
            Z = c.GLFW_KEY_Z,
            Num0 = c.GLFW_KEY_0,
            Num1 = c.GLFW_KEY_1,
            Num2 = c.GLFW_KEY_2,
            Num3 = c.GLFW_KEY_3,
            Num4 = c.GLFW_KEY_4,
            Num5 = c.GLFW_KEY_5,
            Num6 = c.GLFW_KEY_6,
            Num7 = c.GLFW_KEY_7,
            Num8 = c.GLFW_KEY_8,
            Num9 = c.GLFW_KEY_9,
            Comma = c.GLFW_KEY_COMMA,
            Period = c.GLFW_KEY_PERIOD,
            Enter = c.GLFW_KEY_ENTER,
            Space = c.GLFW_KEY_SPACE,
            Backspace = c.GLFW_KEY_BACKSPACE,
            Escape = c.GLFW_KEY_ESCAPE,
            Delete = c.GLFW_KEY_DELETE,
            Tab = c.GLFW_KEY_TAB,
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

            const primary_monitor = c.glfwGetPrimaryMonitor();
            const video_mode = c.glfwGetVideoMode(primary_monitor);
            info(("monitor refrash rate: {d}\n"), .{video_mode.*.refreshRate});
            info(("monitor width: {d}\n"), .{video_mode.*.width});
            info(("monitor height: {d}\n"), .{video_mode.*.height});
            info(("monitor redBits: {d}\n"), .{video_mode.*.redBits});
            info(("monitor greenBits: {d}\n"), .{video_mode.*.greenBits});
            info(("monitor blueBits: {d}\n"), .{video_mode.*.blueBits});

            c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
            c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
            c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
            c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
            c.glfwWindowHint(c.GLFW_OPENGL_DEBUG_CONTEXT, c.GL_TRUE);
            c.glfwWindowHint(c.GLFW_FLOATING, c.GL_TRUE);
            c.glfwSwapInterval(1);

            const maby_glfw_window = c.glfwCreateWindow(config.width, config.height, config.title.ptr, null, null);
            if (maby_glfw_window == null) {
                return WindowError.GlfwCreateWindow;
            }

            const glfw_window = maby_glfw_window.?;
            c.glfwMakeContextCurrent(glfw_window);
            c.glfwSetInputMode(glfw_window, c.GLFW_STICKY_KEYS, c.GLFW_TRUE);

            gl.load({}, glProcAddressGet) catch {
                return WindowError.GladLoadGl;
            };
            _ = c.glfwSetFramebufferSizeCallback(glfw_window, resizeCallback);

            return .{
                .state = init_state,
                .title = config.title,
                .onKey = config.onKey,
                .onLoad = config.onLoad,
                .onDraw = config.onDraw,
                .glfw_window = maby_glfw_window,
                .window_size = .{
                    .width = config.width,
                    .height = config.height,
                },
                .mouse_state = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            c.glfwDestroyWindow(self.glfw_window);
            c.glfwTerminate();
        }

        pub fn drawUntilQuit(self: *Self) anyerror!void {
            if (try self.onLoad(self, &self.state) == .Quit) {
                info("onLoad quit program\n", .{});
                return;
            }

            var previous_time: f32 = @floatCast(f32, c.glfwGetTime());
            var current_time: f32 = @floatCast(f32, c.glfwGetTime());

            while (c.glfwWindowShouldClose(self.glfw_window) != 1) {
                current_time = @floatCast(f32, c.glfwGetTime());
                self.delta_time = previous_time - current_time;
                previous_time = current_time;
                self.frame += 1;
                self.updateWindowSize();
                self.updateMousePosition();
                if (try self.handleInput() == .Quit) {
                    _ = c.glfwSetWindowShouldClose(self.glfw_window, c.GLFW_TRUE);
                    continue;
                }

                gl.clearColor(0.4, 0.4, 0.5, 1);
                gl.clear(gl.COLOR_BUFFER_BIT);
                try self.onDraw(self, &self.state);

                c.glfwSwapBuffers(self.glfw_window);
                c.glfwPollEvents();
            }
        }

        fn updateMousePosition(self: *Self) void {
            var mouse_x: f64 = undefined;
            var mouse_y: f64 = undefined;
            c.glfwGetCursorPos(self.glfw_window, &mouse_x, &mouse_y);
            self.mouse_state.x = @floatToInt(i32, mouse_x);
            self.mouse_state.y = @floatToInt(i32, mouse_y);
        }

        fn updateWindowSize(self: *Self) void {
            c.glfwGetWindowSize(self.glfw_window, &self.window_size.width, &self.window_size.height);
        }

        fn handleInput(self: *Self) anyerror!Action {
            const key_field_list = std.meta.fields(Key);
            var result: Action = .Continue;
            inline for (key_field_list) |field| {
                if (c.glfwGetKey(self.glfw_window, field.value) == c.GLFW_PRESS) {
                    if (!@field(self.key_state, field.name)) {
                        // info("[key press active] {s}\n", .{field.name});
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

            if (c.glfwGetMouseButton(self.glfw_window, c.GLFW_MOUSE_BUTTON_LEFT) == c.GLFW_PRESS) {
                self.mouse_state.button_left_active = true;
            }
            if (c.glfwGetMouseButton(self.glfw_window, c.GLFW_MOUSE_BUTTON_LEFT) == c.GLFW_RELEASE) {
                self.mouse_state.button_left_active = false;
            }
            if (c.glfwGetMouseButton(self.glfw_window, c.GLFW_MOUSE_BUTTON_RIGHT) == c.GLFW_PRESS) {
                self.mouse_state.button_right_active = true;
            }
            if (c.glfwGetMouseButton(self.glfw_window, c.GLFW_MOUSE_BUTTON_RIGHT) == c.GLFW_RELEASE) {
                self.mouse_state.button_right_active = false;
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
