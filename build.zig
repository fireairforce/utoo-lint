const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const util_module = b.createModule(.{
        .root_source_file = b.path("vendor/yuku/src/util/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const parser_module = b.createModule(.{
        .root_source_file = b.path("vendor/yuku/src/parser/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    parser_module.addImport("util", util_module);

    const lint_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lint_module.addImport("parser", parser_module);

    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_module.addImport("utoo_lint", lint_module);

    const exe = b.addExecutable(.{
        .name = "utoo-lint",
        .root_module = exe_module,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run utoo-lint");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_module = lint_module,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
