const std = @import("std");

fn generateCode(b: *std.Build, target: std.Build.ResolvedTarget) *std.Build.Step {
    const bindgen = b.addExecutable(.{ .name = "bindgen", .root_module = b.createModule(.{
        .target = target,
        .optimize = .Debug,
        .root_source_file = b.path("core/lua/bindgen.zig"),
    }) });
    const bindgen_run = b.addRunArtifact(bindgen);
    const bindings_output = bindgen_run.addOutputFileArg("lua_bindings.zig");
    bindgen_run.addFileArg(b.path("core/lua/bindings.json")); // order is important
    bindgen_run.step.dependOn(&bindgen.step);
    const copy_bindings = b.addUpdateSourceFiles();
    copy_bindings.step.dependOn(&bindgen_run.step);
    copy_bindings.addCopyFileToSource(bindings_output, "core/lua/bindings.zig");
    return &copy_bindings.step;
}

fn addCoreModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    // // wren
    // const wren_lib = b.createModule(.{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const wren = b.addLibrary(.{
    //     .name = "wren",
    //     .linkage = .static,
    //     .root_module = wren_lib,
    // });
    // wren.linkLibC();
    // wren.addIncludePath(b.path("externals/wren-0.4.0/src/vm/"));
    // wren.addIncludePath(b.path("externals/wren-0.4.0/src/include/"));
    // wren.addIncludePath(b.path("externals/wren-0.4.0/src/optional/"));
    // wren.addCSourceFiles(.{
    //     .root = b.path("externals/wren-0.4.0/src/"),
    //     .files = &.{
    //         "vm/wren_compiler.c",
    //         "vm/wren_core.c",
    //         "vm/wren_debug.c",
    //         "vm/wren_primitive.c",
    //         "vm/wren_utils.c",
    //         "vm/wren_value.c",
    //         "vm/wren_vm.c",
    //     },
    //     .flags = &.{},
    // });

    // lua
    const lua_lib = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    const lua = b.addLibrary(.{
        .name = "lua",
        .linkage = .static,
        .root_module = lua_lib,
    });
    lua.addIncludePath(b.path("externals/lua-5.5.0/"));
    var lua_sources = std.ArrayList([]const u8).initCapacity(b.allocator, 32) catch unreachable;
    defer lua_sources.deinit(b.allocator);
    lua_sources.appendSlice(b.allocator, &.{
        "lapi.c",
        "patch_lauxlib.c",
        "patch_lbaselib.c",
        "lcode.c",
        "lcorolib.c",
        "lctype.c",
        "ldebug.c",
        "ldump.c",
        "lfunc.c",
        "lgc.c",
        "patch_linit.c",
        "llex.c",
        "lmathlib.c",
        "lmem.c",
        "lobject.c",
        "lopcodes.c",
        "lparser.c",
        "lstate.c",
        "lstring.c",
        "lstrlib.c",
        "ltable.c",
        "ltablib.c",
        "ltm.c",
        "lua.h",
        "lundump.c",
        "lutf8lib.c",
        "lvm.c",
        "lzio.c",
    }) catch unreachable;
    if (target.result.os.tag == .wasi) {
        lua_sources.append(b.allocator, "patch_wasi_ldo.c") catch unreachable;
    } else {
        lua_sources.append(b.allocator, "ldo.c") catch unreachable;
    }
    var lua_flags = std.ArrayList([]const u8).initCapacity(b.allocator, 32) catch unreachable;
    defer lua_flags.deinit(b.allocator);
    if (target.result.os.tag == .wasi) {
        lua_flags.appendSlice(b.allocator, &.{
            "-D_WASI_EMULATED_SIGNAL",
            "-D_WASI_EMULATED_PROCESS_CLOCKS",
            "-DLUAI_THROW(L,c)={return;}",
            "-DLUAI_TRY(L,c,a,u)=a(L,u)",
            "-Dluai_jmpbuf=int",
            "-Djmp_buf=int",
            // "-mllvm",
            // "-wasm-enable-sjlj",
            // "--trace-symbol=fd_write"
        }) catch unreachable;
    }

    lua.addCSourceFiles(.{ .root = b.path("externals/lua-5.5.0/"), .files = lua_sources.items, .flags = lua_flags.items, .language = .c });
    lua.linkLibC();

    // zgltf
    // const zgltf_dep = b.dependency("zgltf", .{ .target = target, .optimize = optimize });
    // zigimg
    // const zigimg_dep = b.dependency("zigimg", .{ .target = target, .optimize = optimize });

    // core
    const core = b.addModule("core", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("core/nux.zig"),
        .imports = &.{
            // .{ .name = "zgltf", .module = zgltf_dep.module("zgltf") },
            // .{ .name = "zigimg", .module = zigimg_dep.module("zigimg") },
            .{ .name = "lua", .module = lua_lib },
            // .{ .name = "wren", .module = wren_lib },
        },
    });
    core.addIncludePath(b.path("externals/wren-0.4.0/src/include/"));
    core.addIncludePath(b.path("externals/lua-5.5.0/"));

    return core;
}

fn configWeb(b: *std.Build) void {
    // configuration
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });
    const wasm_optimize = .ReleaseSmall;
    const standard_target = b.standardTargetOptions(.{});

    // core
    const core = addCoreModule(b, wasm_target, wasm_optimize);
    const codegen = generateCode(b, standard_target);
    // web
    const wasm = b.addExecutable(.{
        .name = "nux",
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtimes/web/main.zig"),
            .target = wasm_target,
            .optimize = wasm_optimize,
            .imports = &.{
                .{ .name = "core", .module = core },
            },
        }),
    });
    // wasm.verbose_cc
    wasm.entry = .disabled;
    wasm.rdynamic = true;
    wasm.wasi_exec_model = .reactor;
    // wasm.import_symbols = true;
    // wasm.max_memory = (1 << 28);
    // wasm.import_symbols
    // wasm.export_memory = true;
    // wasm.import_memory = true;
    // wasm.initial_memory = (1 << 28);

    // install to runtimes/web
    const install = b.addInstallArtifact(wasm, .{ .dest_dir = .{ .override = .{ .custom = "../runtimes/web/" } } });

    // dependencies
    install.step.dependOn(codegen);
    wasm.step.dependOn(codegen);
}
fn configNative(b: *std.Build) void {

    // configuration
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // core
    const core = addCoreModule(b, target, optimize);
    const codegen = generateCode(b, target);
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
    const artifact = b.addExecutable(.{
        .name = "nux",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtimes/native/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = core },
                .{ .name = "gl", .module = zigglgen },
            },
        }),
    });
    artifact.linkLibrary(glfw_lib);
    artifact.addIncludePath(glfw_dep.path("glfw/include/GLFW"));
    artifact.step.dependOn(codegen);

    // install
    const install = b.addInstallArtifact(artifact, .{});
    b.default_step.dependOn(&install.step);

    // run
    const run = b.addRunArtifact(artifact);
    const run_step = b.step("run", "run the console");
    run_step.dependOn(&install.step);
    run_step.dependOn(&run.step);

    // debug
    const debug = b.addSystemCommand(&.{
        "lldb",
        "--",
    });
    debug.addArtifactArg(artifact);
    const debug_step = b.step("debug", "run the console under lldb");
    debug_step.dependOn(&debug.step);

    // valgrind
    const valgrind = b.addSystemCommand(&.{"valgrind"});
    valgrind.addArtifactArg(artifact);
    const valgrind_step = b.step("valgrind", "run the console with valgrind");
    valgrind_step.dependOn(&valgrind.step);

    // tests
    //
    const tests = b.addTest(.{ .root_module = core });
    const tests_run = b.addRunArtifact(tests);
    const tests_step = b.step("test", "run tests");
    tests_step.dependOn(&tests_run.step);
}

pub fn build(b: *std.Build) void {
    const Runtime = enum { native, web };
    const config = b.option(Runtime, "runtime", "Runtime target") orelse .native;
    switch (config) {
        .native => configNative(b),
        .web => configWeb(b),
    }
}
