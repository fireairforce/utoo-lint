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

    const test_module = b.createModule(.{
        .root_source_file = b.path("tests/all.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("utoo_lint", lint_module);

    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const snapshot_module = b.createModule(.{
        .root_source_file = b.path("tests/snapshots/runner.zig"),
        .target = target,
        .optimize = optimize,
    });
    snapshot_module.addImport("utoo_lint", lint_module);

    const snapshot_runner = b.addExecutable(.{
        .name = "rule-snapshots",
        .root_module = snapshot_module,
    });

    const run_snapshot_tests = b.addRunArtifact(snapshot_runner);
    run_snapshot_tests.setCwd(b.path("."));
    const snapshot_test_step = b.step("test-snapshots", "Verify rule snapshots");
    snapshot_test_step.dependOn(&run_snapshot_tests.step);

    const update_snapshot_tests = b.addRunArtifact(snapshot_runner);
    update_snapshot_tests.setCwd(b.path("."));
    update_snapshot_tests.addArg("--update");
    const snapshot_update_step = b.step("update-snapshots", "Update rule snapshots");
    snapshot_update_step.dependOn(&update_snapshot_tests.step);

    const test_step = b.step("test", "Run unit tests and rule snapshots");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_snapshot_tests.step);
}
