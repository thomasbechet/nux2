const std = @import("std");

fn buildCore(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    // ziglua
    const ziglua_dep = b.dependency("ziglua", .{ .target = target, .optimize = optimize, .lang = .lua52 });
    // zgltf
    const zgltf_dep = b.dependency("zgltf", .{ .target = target, .optimize = optimize });
    // zigimg
    const zigimg_dep = b.dependency("zigimg", .{ .target = target, .optimize = optimize });
    // bindgen
    const bindings_exe = b.addExecutable(.{ .name = "bindgen", .root_module = b.createModule(.{
        .target = target,
        .root_source_file = b.path("core/lua/bindgen.zig"),
    }) });
    const run_bindings_exe = b.addRunArtifact(bindings_exe);
    run_bindings_exe.step.dependOn(&bindings_exe.step);
    const bindings_output = run_bindings_exe.addOutputFileArg("bindings.zig");
    run_bindings_exe.addFileArg(b.path("core/lua/modules.json"));

    // core
    const core = b.addModule("core", .{ .target = target, .optimize = optimize, .root_source_file = b.path("core/core.zig"), .imports = &.{ .{ .name = "ziglua", .module = ziglua_dep.module("zlua") }, .{ .name = "zgltf", .module = zgltf_dep.module("zgltf") }, .{ .name = "zigimg", .module = zigimg_dep.module("zigimg") } } });
    core.addAnonymousImport("bindings", .{ .root_source_file = bindings_output, .imports = &.{.{ .name = "ziglua", .module = ziglua_dep.module("zlua") }} });

    return core;
}

pub fn build(b: *std.Build) void {

    // configuration
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // glfw
    const glfw_dep = b.dependency("glfw", .{ .target = target, .optimize = optimize });
    const glfw_lib = glfw_dep.artifact("glfw");
    // zigglgen
    const zigglgen = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.3",
        .profile = .core,
        .extensions = &.{},
    });
    // native
    const native_runtime = b.addExecutable(.{
        .name = "nux",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtimes/native/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = buildCore(b, target, optimize) },
                .{ .name = "gl", .module = zigglgen },
            },
        }),
    });
    b.installArtifact(native_runtime);
    native_runtime.linkLibrary(glfw_lib);
    native_runtime.addIncludePath(glfw_dep.path("glfw/include/GLFW"));

    // web
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });
    const wasm_optimize = .ReleaseSmall;
    const wasm_runtime = b.addExecutable(.{
        .name = "nux",
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtimes/web/main.zig"),
            .target = wasm_target,
            .optimize = wasm_optimize,
            .imports = &.{
                .{ .name = "core", .module = buildCore(b, wasm_target, wasm_optimize) },
            },
        }),
    });
    wasm_runtime.entry = .disabled;
    wasm_runtime.rdynamic = true;
    const wasm_cmd = b.addRunArtifact(wasm_runtime);
    wasm_cmd.step.dependOn(b.getInstallStep());
    const wasm_step = b.step("wasm", "build wasm");
    wasm_step.dependOn(&wasm_cmd.step);

    // run
    const run_step = b.step("run", "run the app");
    const run_cmd = b.addRunArtifact(native_runtime);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // debug
    const lldb = b.addSystemCommand(&.{
        "lldb",
        "--",
    });
    lldb.addArtifactArg(native_runtime);
    const lldb_step = b.step("debug", "run the tests under lldb");
    lldb_step.dependOn(&lldb.step);

    // valgrind
    const valgrind = b.addSystemCommand(&.{"valgrind"});
    valgrind.addArtifactArg(native_runtime);
    const valgrind_step = b.step("valgrind", "run the runtime with valgrind");
    valgrind_step.dependOn(&valgrind.step);

    // tests
    const nux_tests = b.addTest(.{
        .root_module = buildCore(b, target, optimize),
    });
    const run_mod_tests = b.addRunArtifact(nux_tests);
    const exe_tests = b.addTest(.{
        .root_module = native_runtime.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
