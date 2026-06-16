const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-exponentiation-operator for Math.pow calls" {
    const source =
        \\Math.pow(base, exponent);
        \\Math.pow();
        \\Math.pow(base);
        \\Math.pow(base, exponent, modulo);
        \\(Math).pow(2, 8);
        \\Math["pow"](2, 8);
        \\Math[`pow`](2, 8);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.prefer_exponentiation_operator.id));
    try std.testing.expectEqualStrings(
        "Use the exponentiation operator (**) instead of Math.pow.",
        result.diagnostics[0].message,
    );
}

test "does not report prefer-exponentiation-operator for other calls or shadowed Math" {
    const source =
        \\Math.max(base, exponent);
        \\Math[`po${letter}`](base, exponent);
        \\const Math = { pow() {} };
        \\Math.pow(base, exponent);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_exponentiation_operator.id));
}

test "can disable prefer-exponentiation-operator" {
    const source =
        \\Math.pow(base, exponent);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .prefer_exponentiation_operator = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_exponentiation_operator.id));
}
