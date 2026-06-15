const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports dot-notation for computed string properties that can use dot access" {
    const source =
        \\object["property"];
        \\object["_private"];
        \\object["$value"];
        \\object["property1"];
        \\object["default"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.dot_notation.id));
    try std.testing.expectEqualStrings(
        "['property'] is better written in dot notation.",
        result.diagnostics[0].message,
    );
}

test "does not report dot-notation when bracket access is required" {
    const source =
        \\object["not-valid"];
        \\object["123"];
        \\object[""];
        \\object[property];
        \\object[call()];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.dot_notation.id));
}

test "allows keyword properties when allowKeywords is false" {
    const source =
        \\object["default"];
        \\object["class"];
        \\object["property"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation_allow_keywords = .no,
        .eol_last = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.dot_notation.id));
    try std.testing.expectEqualStrings(
        "['property'] is better written in dot notation.",
        result.diagnostics[0].message,
    );
}

test "can disable dot-notation" {
    const source =
        \\object["property"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.dot_notation.id));
}
