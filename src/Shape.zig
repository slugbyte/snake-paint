// import
const std = @import("std");
const c = @import("./c.zig").c;
const gl = @import("./gl.zig");

// alias
const info = std.debug.print;

// self
const Self = @This();
vao_id: c_uint,
vab_id: c_uint,
eab_id: ?c_uint = null,
vertex_count: c_int,

// pub delcs
pub fn init(vertex_list: []const f32) Self {
    var vao_id: c_uint = undefined;
    var vab_id: c_uint = undefined;

    // create
    gl.genVertexArrays(1, &vao_id);
    gl.genBuffers(1, &vab_id);

    // bind
    gl.bindVertexArray(vao_id);
    gl.bindBuffer(gl.ARRAY_BUFFER, vab_id);

    // pack
    const vab_id_size = @intCast(c_int, vertex_list.len) * @sizeOf(f32);
    gl.bufferData(gl.ARRAY_BUFFER, vab_id_size, vertex_list.ptr, gl.STATIC_DRAW);

    // describe
    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    return .{
        .vao_id = vao_id,
        .vab_id = vab_id,
        .vertex_count = @intCast(c_int, vertex_list.len / 2),
    };
}

pub fn initWithIndexBuffer(vertex_list: []const f32, index_list: []const c_uint) Self {
    var vao_id: c_uint = undefined;
    var vab_id: c_uint = undefined;
    var eab_id: c_uint = undefined;

    // create
    gl.genVertexArrays(1, &vao_id);
    gl.genBuffers(1, &vab_id);
    gl.genBuffers(1, &eab_id);

    // bind
    gl.bindVertexArray(vao_id);
    gl.bindBuffer(gl.ARRAY_BUFFER, vab_id);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, eab_id);

    // pack
    const vab_size = @intCast(c_int, vertex_list.len) * @sizeOf(f32);
    gl.bufferData(gl.ARRAY_BUFFER, vab_size, vertex_list.ptr, gl.STATIC_DRAW);

    const eab_size = @intCast(c_int, index_list.len) * @sizeOf(f32);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, eab_size, index_list.ptr, gl.STATIC_DRAW);

    // describe
    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), null);
    gl.enableVertexAttribArray(0);

    return .{
        .vao_id = vao_id,
        .vab_id = vab_id,
        .eab_id = eab_id,
        .vertex_count = @intCast(c_int, index_list.len),
    };
}

pub fn render(self: *Self) void {
    if (self.eab_id != null) {
        gl.bindVertexArray(self.vao_id);
        gl.drawElements(gl.TRIANGLES, self.vertex_count, gl.UNSIGNED_INT, null);
        return;
    }

    gl.bindVertexArray(self.vao_id);
    gl.drawArrays(gl.TRIANGLES, 0, self.vertex_count);
}
