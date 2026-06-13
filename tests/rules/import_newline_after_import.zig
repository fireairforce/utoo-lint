const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports import/newline-after-import when code follows import without a blank line" {
    const source =
        \\import thing from "./thing";
        \\const value = thing;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.import_newline_after_import.id));
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "allows grouped imports and a blank line before code" {
    const source =
        \\import thing from "./thing";
        \\import other from "./other";
        \\
        \\const value = thing || other;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_newline_after_import.id));
}

test "can disable import/newline-after-import" {
    const source =
        \\import thing from "./thing";
        \\const value = thing;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .import_newline_after_import = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_newline_after_import.id));
}
