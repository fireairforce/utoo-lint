const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports unsorted variables in the same declaration" {
    const source =
        \\let alpha, beta;
        \\const zebra = 1, apple = 2, carrot = 3;
        \\var delta, charlie, echo;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.sort_vars.id));
    try std.testing.expect(hasMessage(result, "Variables within the same declaration block should be sorted alphabetically."));
}

test "keeps later comparisons anchored to the last sorted variable" {
    const source =
        \\let c, d, a, b, e;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.sort_vars.id));
}

test "supports ignoreCase" {
    const source =
        \\let B, a;
    ;

    var sensitive_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer sensitive_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(sensitive_result, lint.rules.sort_vars.id));

    var options = baseOptions();
    options.sort_vars_ignore_case = true;
    var insensitive_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer insensitive_result.deinit(std.testing.allocator);
    try std.testing.expect(helpers.hasRule(insensitive_result, lint.rules.sort_vars.id));
}

test "autofixes identifier declarators into alphabetical order" {
    const source =
        \\let beta = 2, alpha = 1, charlie = 3;
        \\let charlie = 3, delta = 4, alpha = 1, beta = 2;
    ;
    const expected =
        \\let alpha = 1, beta = 2, charlie = 3;
        \\let alpha = 1, beta = 2, charlie = 3, delta = 4;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.sort_vars.id));
}

test "autofix preserves declaration formatting and destructuring positions" {
    const source =
        \\var delta,
        \\    alpha = 1,
        \\    [middle] = values,
        \\    beta = 2;
    ;
    const expected =
        \\var alpha = 1,
        \\    beta = 2,
        \\    [middle] = values,
        \\    delta;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.sort_vars.id));
}

test "does not autofix declarations with non-literal identifier initializers" {
    const source =
        \\let beta = 1, alpha = compute();
        \\let delta = 4, charlie = delta;
        \\let zebra = 0, apple = `${zebra}`;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result.result, lint.rules.sort_vars.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.sort_vars.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "autofix supports ignoreCase and preserves comments around literal declarations" {
    const source =
        \\let Bravo = /b/ /* keep */, /* between */ alpha = (1);
    ;
    const expected =
        \\let alpha = (1) /* keep */, /* between */ Bravo = /b/;
    ;

    var options = baseOptions();
    options.sort_vars_ignore_case = true;
    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.sort_vars.id));
}

test "ignores destructuring declarators and can disable rule" {
    const source =
        \\let z, { a } = value, y;
    ;

    var enabled_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer enabled_result.deinit(std.testing.allocator);
    try std.testing.expect(helpers.hasRule(enabled_result, lint.rules.sort_vars.id));

    var options = baseOptions();
    options.sort_vars = false;
    var disabled_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer disabled_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(disabled_result, lint.rules.sort_vars.id));
}

fn baseOptions() lint.Options {
    return .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .one_var = false,
        .prefer_const = false,
        .parser_semantic_errors = false,
        .sort_vars = true,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.sort_vars.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
