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

test "reports import/newline-after-import when configured count is not met" {
    const source =
        \\import thing from "./thing";
        \\
        \\const value = thing;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .import_newline_after_import_count = 2,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.import_newline_after_import.id));
}

test "allows import/newline-after-import when configured count is met" {
    const source =
        \\import thing from "./thing";
        \\
        \\
        \\const value = thing;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .import_newline_after_import_count = 2,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.import_newline_after_import.id));
}

test "reports import/newline-after-import when exactCount rejects extra blank lines" {
    const source =
        \\import thing from "./thing";
        \\
        \\
        \\const value = thing;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .import_newline_after_import_count = 1,
        .import_newline_after_import_exact_count = true,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.import_newline_after_import.id));
}

test "supports configured import/newline-after-import count options" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        \\["error", {"count": 2, "exactCount": true}]
    ,
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("import/newline-after-import", config.value);

    try std.testing.expect(options.import_newline_after_import);
    try std.testing.expectEqual(@as(usize, 2), options.import_newline_after_import_count);
    try std.testing.expect(options.import_newline_after_import_exact_count);
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
