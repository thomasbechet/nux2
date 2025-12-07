const std = @import("std");

pub fn build(b: *std.Build) void {

    // Configuration
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core
    const nux = b.addModule("nux", .{
        .root_source_file = b.path("core/core.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Runtime
    const exe = b.addExecutable(.{
        .name = "nux",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtimes/native/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "nux", .module = nux },
            },
        }),
    });
    b.installArtifact(exe);

    // GLFW
    const glfw_dep = b.dependency("glfw", .{ .target = target, .optimize = optimize });
    const glfw_lib = glfw_dep.artifact("glfw");
    exe.linkLibrary(glfw_lib);
    exe.addIncludePath(glfw_dep.path("glfw/include/GLFW"));

    // Run
    const run_step = b.step("run", "run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Tests
    const nux_tests = b.addTest(.{
        .root_module = nux,
    });
    const run_mod_tests = b.addRunArtifact(nux_tests);
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // LLDB
    const lldb = b.addSystemCommand(&.{
        "lldb",
        "--",
    });
    lldb.addArtifactArg(exe);
    const lldb_step = b.step("debug", "run the tests under lldb");
    lldb_step.dependOn(&lldb.step);

    // Valgrind
    const valgrind = b.addSystemCommand(&.{"valgrind"});
    valgrind.addArtifactArg(exe);
    const valgrind_step = b.step("valgrind", "run the runtime with valgrind");
    valgrind_step.dependOn(&valgrind.step);
}
