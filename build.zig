const std     = @import("std");

pub fn build(b: *std.Build) void {

    	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});
    
    const exe = b.addExecutable(.{
        .name = "glfw-test",
		.root_source_file = b.path("glfw-test.zig"),
		.target = target, .optimize = optimize,
    });
    
    const zglfw = b.dependency("zglfw", .{});
    exe.root_module.addImport("zglfw", zglfw.module("root"));

    if (target.result.os.tag != .emscripten) {
        exe.linkLibrary(zglfw.artifact("glfw"));
    }

    const zopengl = b.dependency("zopengl", .{});
    exe.root_module.addImport("zopengl", zopengl.module("root"));
    

    // Usually this is b.installArtifact(exe), but that is just the line below
    // with default options.
    const install_artifact = b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = .prefix },
    });
    b.getInstallStep().dependOn(&install_artifact.step);

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());
    
	const run_step = b.step("run", "run the game");
	run_step.dependOn(&run_exe.step);
}
