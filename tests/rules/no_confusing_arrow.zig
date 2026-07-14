const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-confusing-arrow for unparenthesized conditional expression bodies" {
    const source =
        \\const first = value => value ? firstValue : secondValue;
        \\const second = (value) => value ? firstValue : secondValue;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_confusing_arrow.id));
    try std.testing.expectEqualStrings(
        "Arrow function used ambiguously with a conditional expression.",
        result.diagnostics[0].message,
    );
}

test "allows parenthesized conditional expression bodies and block bodies" {
    const source =
        \\const first = value => (value ? firstValue : secondValue);
        \\const second = value => {
        \\  return value ? firstValue : secondValue;
        \\};
        \\const third = value => value || fallback;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_confusing_arrow.id));
}

test "reports parenthesized conditional expression bodies when allowParens is false" {
    const source =
        \\const first = value => (value ? firstValue : secondValue);
        \\const second = value => {
        \\  return value ? firstValue : secondValue;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_confusing_arrow_allow_parens = .no,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_confusing_arrow.id));
}

test "autofixes confusing arrow bodies when parentheses are allowed" {
    const source =
        \\const first = value => value ? firstValue : secondValue;
        \\const second = value => value /* keep */ ? firstValue : secondValue;
    ;
    const expected =
        \\const first = value => (value ? firstValue : secondValue);
        \\const second = value => (value /* keep */ ? firstValue : secondValue);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_confusing_arrow.id));
}

test "does not autofix confusing arrows when allowParens is false" {
    const source =
        \\const first = value => value ? firstValue : secondValue;
        \\const second = value => (value ? firstValue : secondValue);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_confusing_arrow_allow_parens = .no,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result.result, lint.rules.no_confusing_arrow.id));
}

test "can disable no-confusing-arrow" {
    const source = "const first = value => value ? firstValue : secondValue;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_confusing_arrow = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_confusing_arrow.id));
}
