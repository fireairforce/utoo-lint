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
        .no_undef = false,
        .no_unused_vars = false,
        .one_var = false,
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
