const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlm_module = b.addModule("zlm", .{
        .source_file = .{ .path = "./res/package/zlm/src/zlm.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "okpt",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath("res/include");
    exe.addLibraryPath("res/lib");
    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("gl");
    exe.linkLibC();
    exe.addModule("zlm", zlm_module);
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
