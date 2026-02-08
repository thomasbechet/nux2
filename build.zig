const std = @import("std");

const Config = struct {
    const Platform = enum {
        native,
        web,
    };
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    platform: Platform,
};

fn configCore(b: *std.Build, config: Config) void {
    // wren
    const wren_mod = b.createModule(.{
        .target = config.target,
        .optimize = config.optimize,
    });
    const wren = b.addLibrary(.{
        .name = "wren",
        .linkage = .static,
        .root_module = wren_mod,
    });
    wren.linkLibC();
    wren.addIncludePath(b.path("externals/wren-0.4.0/src/vm/"));
    wren.addIncludePath(b.path("externals/wren-0.4.0/src/include/"));
    wren.addIncludePath(b.path("externals/wren-0.4.0/src/optional/"));
    wren.addCSourceFiles(.{
        .root = b.path("externals/wren-0.4.0/src/"),
        .files = &.{
            "vm/wren_compiler.c",
            "vm/wren_core.c",
            "vm/wren_debug.c",
            "vm/wren_primitive.c",
            "vm/wren_utils.c",
            "vm/wren_value.c",
            "vm/wren_vm.c",
        },
        .flags = &.{},
    });

    // lua
    const lua_mod = b.createModule(.{
        .target = config.target,
        .optimize = config.optimize,
    });
    const lua = b.addLibrary(.{
        .name = "lua",
        .linkage = .static,
        .root_module = lua_mod,
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
    if (config.target.result.os.tag == .wasi) {
        lua_sources.append(b.allocator, "patch_wasi_ldo.c") catch unreachable;
    } else {
        lua_sources.append(b.allocator, "ldo.c") catch unreachable;
    }
    var lua_flags = std.ArrayList([]const u8).initCapacity(b.allocator, 32) catch unreachable;
    defer lua_flags.deinit(b.allocator);
    if (config.target.result.os.tag == .wasi) {
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

    // clay
    const zclay_pkg = b.dependency("zclay", .{ .target = config.target, .optimize = config.optimize });

    // zgltf
    const zgltf_pkg = b.dependency("zgltf", .{ .target = config.target, .optimize = config.optimize });

    // zigimg
    const zigimg_pkg = b.dependency("zigimg", .{ .target = config.target, .optimize = config.optimize });

    // bindings
    const bindgen = b.addExecutable(.{ .name = "bindgen", .root_module = b.createModule(.{
        .target = config.target,
        .optimize = .Debug,
        .root_source_file = b.path("core/lua/bindgen.zig"),
    }) });
    const bindgen_run = b.addRunArtifact(bindgen);
    bindgen_run.has_side_effects = true;
    const bindings_output_tmp = bindgen_run.addOutputFileArg("bindings.zig");
    bindgen_run.addFileArg(b.path("core/lua/bindings.json"));
    const bindings_copy = b.addUpdateSourceFiles();
    bindings_copy.step.dependOn(&bindgen_run.step);
    bindings_copy.addCopyFileToSource(bindings_output_tmp, "core/lua/bindings.zig");
    const bindgen_step = b.step("bindgen", "Generate bindings");
    bindgen_step.dependOn(&bindings_copy.step);

    // core
    const core = b.addModule("nux", .{
        .target = config.target,
        .optimize = config.optimize,
        .root_source_file = b.path("core/nux.zig"),
        .imports = &.{
            .{ .name = "zgltf", .module = zgltf_pkg.module("zgltf") },
            .{ .name = "zigimg", .module = zigimg_pkg.module("zigimg") },
            .{ .name = "lua", .module = lua_mod },
            .{ .name = "wren", .module = wren_mod },
            .{ .name = "zclay", .module = zclay_pkg.module("zclay") },
        },
    });
    core.addIncludePath(b.path("externals/wren-0.4.0/src/include/"));
    core.addIncludePath(b.path("externals/lua-5.5.0/"));

    // tests
    const tests = b.addTest(.{ .root_module = core });
    const tests_run = b.addRunArtifact(tests);
    const tests_step = b.step("test", "Run tests");
    tests_step.dependOn(&tests_run.step);
}

fn configNative(b: *std.Build, config: Config) void {

    // glfw
    const glfw_dep = b.dependency("glfw", .{ .target = config.target, .optimize = config.optimize });
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
            .target = config.target,
            .optimize = config.optimize,
            .imports = &.{
                .{ .name = "nux", .module = b.modules.get("nux").? },
                .{ .name = "gl", .module = zigglgen },
            },
        }),
    });
    artifact.linkLibrary(glfw_lib);
    artifact.addIncludePath(glfw_dep.path("glfw/include/GLFW"));

    // install
    const install = b.addInstallArtifact(artifact, .{});
    b.default_step.dependOn(&install.step);

    // run
    const run = b.addRunArtifact(artifact);
    // if (b.args) |args| {
    //     run.addArgs(args);
    // }
    const run_step = b.step("run", "Run the console");
    run_step.dependOn(&install.step);
    run_step.dependOn(&run.step);

    // lldb
    const lldb = b.addSystemCommand(&.{
        "lldb",
        "--",
    });
    lldb.addArtifactArg(artifact);
    const lldb_step = b.step("lldb", "Run the console under lldb");
    lldb_step.dependOn(&lldb.step);

    // gdb
    const gdb = b.addSystemCommand(&.{
        "gdb",
        "--",
    });
    gdb.addArtifactArg(artifact);
    const gdb_step = b.step("gdb", "Run the console under gdb");
    gdb_step.dependOn(&gdb.step);

    // valgrind
    const valgrind = b.addSystemCommand(&.{"valgrind"});
    valgrind.addArtifactArg(artifact);
    const valgrind_step = b.step("valgrind", "Run the console with valgrind");
    valgrind_step.dependOn(&valgrind.step);
}
fn configWeb(b: *std.Build, config: Config) void {

    // web
    const wasm = b.addExecutable(.{
        .name = "nux",
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtimes/web/main.zig"),
            .target = config.target,
            .optimize = config.optimize,
            .imports = &.{
                .{ .name = "nux", .module = b.modules.get("nux").? },
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
    b.default_step.dependOn(&install.step);
}

pub fn build(b: *std.Build) void {
    const platform = b.option(Config.Platform, "platform", "target platform") orelse .native;

    const config: Config = .{
        .target = switch (platform) {
            .native => b.standardTargetOptions(.{}),
            .web => b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
            }),
        },
        .optimize = switch (platform) {
            .native => b.standardOptimizeOption(.{}),
            .web => .ReleaseSmall,
        },
        .platform = platform,
    };

    configCore(b, config);
    switch (config.platform) {
        .native => configNative(b, config),
        .web => configWeb(b, config),
    }
}
