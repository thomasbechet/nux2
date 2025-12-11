const std = @import("std");

pub fn build(b: *std.Build) void {

    // Configuration
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core
    const core = b.addModule("core", .{ .target = target, .optimize = optimize, .root_source_file = b.path("core/core.zig"), .imports = &.{} });

    // Runtime
    const runtime = b.addExecutable(.{
        .name = "nux",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtimes/native/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "nux", .module = core },
            },
        }),
    });
    b.installArtifact(runtime);

    // GLFW
    const glfw_dep = b.dependency("glfw", .{ .target = target, .optimize = optimize });
    const glfw_lib = glfw_dep.artifact("glfw");
    runtime.linkLibrary(glfw_lib);
    runtime.addIncludePath(glfw_dep.path("glfw/include/GLFW"));

    // Run
    const run_step = b.step("run", "run the app");
    const run_cmd = b.addRunArtifact(runtime);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Tests
    const nux_tests = b.addTest(.{
        .root_module = core,
    });
    const run_mod_tests = b.addRunArtifact(nux_tests);
    const exe_tests = b.addTest(.{
        .root_module = runtime.root_module,
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
    lldb.addArtifactArg(runtime);
    const lldb_step = b.step("debug", "run the tests under lldb");
    lldb_step.dependOn(&lldb.step);

    // Valgrind
    const valgrind = b.addSystemCommand(&.{"valgrind"});
    valgrind.addArtifactArg(runtime);
    const valgrind_step = b.step("valgrind", "run the runtime with valgrind");
    valgrind_step.dependOn(&valgrind.step);
}
