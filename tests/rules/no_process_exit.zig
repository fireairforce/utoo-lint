const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-process-exit for process exit calls" {
    const source =
        \\process.exit(1);
        \\process["exit"](0);
        \\(process.exit)();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_process_exit.id));
}

test "does not report no-process-exit for references or other objects" {
    const source =
        \\const exit = process.exit;
        \\runner.exit(1);
        \\process[method](0);
        \\process.exitCode = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_process_exit.id));
}

test "can disable no-process-exit" {
    const source =
        \\process.exit(1);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_process_exit = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_process_exit.id));
}
