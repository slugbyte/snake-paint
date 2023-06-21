// import
const std = @import("std");
const gl = @import("./gl.zig");
const zlm = @import("zlm");

// alias
const Allocator = std.mem.Allocator;
const info = std.debug.print;

// data types
pub const Error = error{
    EParseVertexBlockNoBegin,
    EParseVertexBlockNoEnd,
    EParseFragmentBlockNoBegin,
    EParseFragmentBlockNoEnd,
    ECompileShaderVertex,
    ECompileShaderFragment,
    ELinkProgram,
    EOutOfMemory,
};

pub const BlockType = enum(c_uint) {
    Vertex = gl.VERTEX_SHADER,
    Fragment = gl.FRAGMENT_SHADER,
};

const BlockLocation = struct {
    begin: usize,
    end: usize,
    length: c_int,

    /// parse the location of a vertex shader block or a fragment shader block in
    /// a glsl file that contains #vertex_begin/#vertex_end or
    /// #fragment_begin/#fragment_end
    pub fn parse(source: []const u8, comptime block_type: BlockType) Error!BlockLocation {
        const needle_name = switch (block_type) {
            BlockType.Vertex => "#vertex",
            BlockType.Fragment => "#fragment",
        };

        var begin: usize = undefined;
        var end: usize = undefined;

        if (std.mem.indexOf(u8, source, needle_name ++ "_begin")) |index| {
            begin = index + switch (block_type) {
                .Vertex => 14,
                .Fragment => 16,
            };
        } else {
            return switch (block_type) {
                .Vertex => Error.EParseVertexBlockNoBegin,
                .Fragment => Error.EParseFragmentBlockNoBegin,
            };
        }
        if (std.mem.indexOf(u8, source, needle_name ++ "_end")) |index| {
            end = index - 1;
        } else {
            return switch (block_type) {
                .Vertex => Error.EParseVertexBlockNoEnd,
                .Fragment => Error.EParseFragmentBlockNoEnd,
            };
        }
        return .{
            .begin = begin,
            .end = end,
            .length = @intCast(c_int, end - begin),
        };
    }
};

// Self
const Self = @This();
program_id: c_uint,
name: []const u8,
allocator: Allocator,

// pub delcs
pub fn init(allocator: Allocator, name: []const u8, source: []const u8) Error!Self {
    var vertex_shader_id: c_uint = try parseAndCompileShaderBlock(allocator, name, source, .Vertex);
    var fragment_shader_id: c_uint = try parseAndCompileShaderBlock(allocator, name, source, .Fragment);

    var program_id: c_uint = gl.createProgram();
    gl.attachShader(program_id, vertex_shader_id);
    gl.attachShader(program_id, fragment_shader_id);
    gl.linkProgram(program_id);
    try Self.checkTroubleELinkProgram(allocator, name, program_id);

    return .{
        .allocator = allocator,
        .name = name,
        .program_id = program_id,
    };
}

pub fn deinit(self: Self) void {
    gl.deleteShader(self.vertex_shader_id);
    gl.deleteShader(self.fragment_shader_id);
    gl.deleteProgram(self.program_id);
}

pub fn bind(self: *Self) void {
    gl.useProgram(self.program_id);
}

pub fn unbind(self: *Self) void {
    _ = self;
    gl.useProgram(0);
}

pub fn setUniformVec3(self: *Self, name: []const u8, x: f32, y: f32, z: f32) void {
    const uniform_location = gl.getUniformLocation(self.program_id, name.ptr);
    gl.uniform3f(uniform_location, x, y, z);
}

pub fn setUniformVec4(self: *Self, name: []const u8, x: f32, y: f32, z: f32, w: f32) void {
    const uniform_location = gl.getUniformLocation(self.program_id, name.ptr);
    gl.uniform4f(uniform_location, x, y, z, w);
}

pub fn setUniformFloat(self: *Self, name: []const u8, value: f32) void {
    const uniform_location = gl.getUniformLocation(self.program_id, name.ptr);
    gl.uniform1f(uniform_location, value);
}

pub fn setUniformVec2(self: *Self, name: []const u8, x: f32, y: f32) void {
    const uniform_location = gl.getUniformLocation(self.program_id, name.ptr);
    gl.uniform2f(uniform_location, x, y);
}

pub fn setUniformMat4(self: *Self, name: []const u8, matrix: zlm.Mat4) void {
    const data: []f32 = &matrix.fields[0] ++ &matrix.fields[1] ++ &matrix.fields[2] ++ &matrix.fields[3];
    const uniform_location = gl.getUniformLocation(self.program_id, name.ptr);
    gl.uniformMatrix4fv(uniform_location, 16, gl.FALSE, data.ptr);
}

// pravate delcs
/// parse a block_type block and compile it and retrun the id assigned by gl.createShader
fn parseAndCompileShaderBlock(allocator: Allocator, name: []const u8, source: []const u8, comptime block_type: BlockType) Error!c_uint {
    const block_location = try BlockLocation.parse(source, block_type);
    var block_source: []const u8 = source[block_location.begin..block_location.end];
    info("Shader({s}) {}\n", .{ name, block_type });
    var source_line_list = std.mem.split(u8, block_source, "\n");
    var line_number: usize = 1;
    while (source_line_list.next()) |line| {
        info("{d:->3}| {s}\n", .{ line_number, line });
        line_number += 1;
    }

    var blockid: c_uint = gl.createShader(@enumToInt(block_type));
    gl.shaderSource(blockid, 1, &block_source.ptr, @ptrCast([*c]const c_int, &block_location.length));
    gl.compileShader(blockid);

    try Self.checkTroubleECompileShader(allocator, name, blockid, BlockType.Vertex);
    return blockid;
}

fn checkTroubleECompileShader(allocator: Allocator, name: []const u8, shader_id: c_uint, block_type: BlockType) Error!void {
    var is_success: c_int = undefined;
    gl.getShaderiv(shader_id, gl.COMPILE_STATUS, &is_success);
    if (is_success != gl.TRUE) {
        var log_length: c_int = undefined;
        gl.getShaderiv(shader_id, gl.INFO_LOG_LENGTH, &log_length);
        var error_messsage: []u8 = allocator.alloc(u8, @intCast(usize, log_length)) catch |err| {
            info("Error EOutOfMemory ({s})\n", .{name});
            return switch (err) {
                Allocator.Error.OutOfMemory => Error.EOutOfMemory,
            };
        };
        defer allocator.free(error_messsage);
        errdefer allocator.free(error_messsage);

        info("Error ECompileShader ({s})\n", .{name});
        gl.getShaderInfoLog(shader_id, log_length, null, error_messsage.ptr);

        var error_message_line_list = std.mem.split(u8, error_messsage, "\n");
        while (error_message_line_list.next()) |line| {
            info("--- {s}", .{line});
        }
        return switch (block_type) {
            BlockType.Vertex => Error.ECompileShaderVertex,
            BlockType.Fragment => Error.ECompileShaderFragment,
        };
    }
}

fn checkTroubleELinkProgram(allocator: Allocator, name: []const u8, program_id: c_uint) Error!void {
    var is_success: c_int = undefined;
    gl.getProgramiv(program_id, gl.LINK_STATUS, &is_success);
    if (is_success != gl.TRUE) {
        var log_length: c_int = undefined;
        gl.getProgramiv(program_id, gl.INFO_LOG_LENGTH, &log_length);
        var error_messsage: []u8 = allocator.alloc(u8, @intCast(usize, log_length)) catch |err| {
            info("Error EOutOfMemory ({s})\n", .{name});
            return switch (err) {
                Allocator.Error.OutOfMemory => Error.EOutOfMemory,
            };
        };
        defer allocator.free(error_messsage);
        errdefer allocator.free(error_messsage);

        info("Error ELinkProgram ({s})\n", .{name});
        gl.getProgramInfoLog(program_id, log_length, null, error_messsage.ptr);
        var error_message_line_list = std.mem.split(u8, error_messsage, "\n");
        while (error_message_line_list.next()) |line| {
            info("--- {s}", .{line});
        }
        return Error.ELinkProgram;
    }
}
