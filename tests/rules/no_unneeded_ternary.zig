const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unneeded-ternary for boolean literal branches" {
    const source =
        \\const first = enabled ? true : false;
        \\const second = enabled ? false : true;
        \\const third = enabled ? true : true;
        \\const fourth = enabled ? false : false;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_unneeded_ternary.id));
}

test "does not report no-unneeded-ternary for non-boolean branches or default assignments" {
    const source =
        \\const first = enabled ? value : fallback;
        \\const second = enabled ? enabled : fallback;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unneeded_ternary.id));
}

test "supports configured no-unneeded-ternary defaultAssignment false" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"defaultAssignment\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-unneeded-ternary", config.value);
    options.no_ternary = false;
    options.no_constant_condition = false;
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\const first = enabled ? enabled : fallback;
        \\const second = (ready) ? (ready) : fallback;
        \\const third = enabled ? value : enabled;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unneeded_ternary.id));
}

test "autofixes unnecessary boolean ternaries" {
    const source =
        \\const first = value ? true : false;
        \\const second = value ? false : true;
        \\const third = value === 1 ? false : true;
        \\const fourth = value >= 1 ? true : false;
        \\const fifth = !value ? true : false;
        \\const sixth = value ? false : false;
    ;
    const expected =
        \\const first = !!value;
        \\const second = !value;
        \\const third = value !== 1;
        \\const fourth = value >= 1;
        \\const fifth = !value;
        \\const sixth = false;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_unneeded_ternary.id));
}

test "autofix preserves precedence while negating boolean ternaries" {
    const source =
        \\const first = left + right ? false : true;
        \\const second = load() ? false : true;
        \\const third = value instanceof Type ? false : true;
        \\const fourth = value != 1 ? false : true;
        \\const fifth = (left || right) ? true : false;
    ;
    const expected =
        \\const first = !(left + right);
        \\const second = !load();
        \\const third = !(value instanceof Type);
        \\const fourth = value == 1;
        \\const fifth = !!(left || right);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .eqeqeq = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_unneeded_ternary.id));
}

test "autofixes configured default assignments" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"defaultAssignment\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("no-unneeded-ternary", config.value);

    const source =
        \\const first = value ? value : fallback;
        \\const second = value ? value : ready ? yes : no;
        \\const third = value ? value : item => item;
        \\const fourth = value ? value : left ?? right;
        \\const fifth = ((value)) ? (((value))) : (((fallback)));
    ;
    const expected =
        \\const first = value || fallback;
        \\const second = value || (ready ? yes : no);
        \\const third = value || (item => item);
        \\const fourth = value || (left ?? right);
        \\const fifth = ((value)) || (((fallback)));
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_unneeded_ternary.id));
}

test "autofix preserves TypeScript expression grouping" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"defaultAssignment\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("no-unneeded-ternary", config.value);

    const source =
        \\const first = (value as unknown) ? false : true;
        \\const second = value ? value : fallback as unknown;
    ;
    const expected =
        \\const first = !(value as unknown);
        \\const second = value || (fallback as unknown);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_unneeded_ternary.id));
}

test "does not autofix side-effectful equal branches or discard comments" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"defaultAssignment\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .capitalized_comments = false,
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("no-unneeded-ternary", config.value);

    const source =
        \\const first = load() ? false : false;
        \\const second = value ? /* keep */ true : false;
        \\const third = value ? value /* keep */ : fallback;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result.result, lint.rules.no_unneeded_ternary.id));
}

test "can disable no-unneeded-ternary" {
    const source =
        \\const value = enabled ? true : false;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unneeded_ternary = false,
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unneeded_ternary.id));
}
