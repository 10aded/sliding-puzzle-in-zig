const std = @import("std");

pub fn build(b: *std.Build) void {

    const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});
    
    const zglfw_dep = b.dependency("zglfw_dep", .{
        .target = target,
        .optimize = optimize,
    });

    const zopengl_dep = b.dependency("zopengl_dep", .{
        .target = target,
        // .optimize = optimize, // Causes a compile error; not currently a valid option for zopengl.
    });    

    const exe = b.addExecutable(.{
        .name = "sliding-puzzle",
        .root_module = b.createModule(.{
		    .root_source_file = b.path("main.zig"),
		    .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "zglfw",
                    .module = zglfw_dep.module("root"),
                },
                .{
                    .name = "zopengl",
                    .module = zopengl_dep.module("root"),
                },
            },
        }),
    });

    if (target.result.os.tag != .emscripten) {
        exe.root_module.linkLibrary(zglfw_dep.artifact("glfw"));
    }

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
