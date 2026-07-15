const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports yoda for literals on the left side" {
    const source =
        \\if ("red" === color) {}
        \\if (0 < count) {}
        \\if (true !== enabled) {}
        \\if (`ready` == state) {}
        \\if (-1 >= value) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eqeqeq = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.yoda.id));
}

test "autofixes literals onto the expected comparison side" {
    const source =
        \\if ("red" === color) {}
        \\if (0 < count) {}
        \\if (true !== enabled) {}
        \\if (-1 >= value) {}
    ;
    const expected =
        \\if (color === "red") {}
        \\if (count > 0) {}
        \\if (enabled !== true) {}
        \\if (value <= -1) {}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eqeqeq = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.yoda.id));
}

test "autofix preserves comments, spacing, and parenthesized operands" {
    const source =
        \\if ( /* a */ 0 /* b */ < /* c */ value /* d */ ) {}
        \\if (0 /* < decoy */ < value) {}
        \\while (0 === (current = next));
    ;
    const expected =
        \\if ( /* a */ value /* b */ > /* c */ 0 /* d */ ) {}
        \\if (value /* < decoy */ > 0) {}
        \\while ((current = next) === 0);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .curly = false,
        .eqeqeq = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.yoda.id));
}

test "autofix separates moved operands from adjacent outer tokens" {
    const source =
        \\const inside = 0 < lookup()in values;
        \\const typed = 1 > current++instanceof Number;
        \\const matched = /x/ < lookup()in values;
    ;
    const expected =
        \\const inside = lookup() > 0 in values;
        \\const typed = current++ < 1 instanceof Number;
        \\const matched = lookup() > /x/ in values;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.yoda.id));
}

test "autofix protects moved operands adjacent to yield" {
    const source =
        \\function* run() {
        \\  yield(1) < value;
        \\  yield(1) < ++value;
        \\  yield(1) < (value);
        \\}
    ;
    const expected =
        \\function* run() {
        \\  yield value > (1);
        \\  yield++value > (1);
        \\  yield(value) > (1);
        \\}
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
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.yoda.id));
}

test "does not report yoda when literals are on the right side or both sides" {
    const source =
        \\if (color === "red") {}
        \\if (count > 0) {}
        \\if (enabled !== true) {}
        \\if ("red" === "blue") {}
        \\if (value in object) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eqeqeq = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.yoda.id));
}

test "reports yoda always when literals are on the right side" {
    const source =
        \\if (color === "red") {}
        \\if (count > 0) {}
        \\if (enabled !== true) {}
        \\if (state == `ready`) {}
        \\if (value <= -1) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .yoda_style = .always,
        .eqeqeq = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.yoda.id));
    try std.testing.expectEqualStrings("Expected literal to be on the left side of comparison.", result.diagnostics[0].message);
}

test "autofixes comparisons configured for yoda always" {
    const source =
        \\if (color == "red") {}
        \\if (count > 0) {}
        \\if (value <= -1) {}
    ;
    const expected =
        \\if ("red" == color) {}
        \\if (0 < count) {}
        \\if (-1 >= value) {}
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .yoda_style = .always,
        .eqeqeq = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.yoda.id));
}

test "allows yoda always when literals are on the left side or both sides" {
    const source =
        \\if ("red" === color) {}
        \\if (0 < count) {}
        \\if (true !== enabled) {}
        \\if ("red" === "blue") {}
        \\if (value in object) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .yoda_style = .always,
        .eqeqeq = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.yoda.id));
}

test "supports configured yoda onlyEquality option" {
    const source =
        \\if ("red" === color) {}
        \\if (0 < count) {}
        \\if (value >= -1) {}
    ;

    var options = lint.Options{
        .eqeqeq = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"onlyEquality\":true}]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue("yoda", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.yoda.id));
}

test "autofix respects configured yoda onlyEquality" {
    const source =
        \\if ("red" === color) {}
        \\if (0 < count) {}
    ;
    const expected =
        \\if (color === "red") {}
        \\if (0 < count) {}
    ;

    var options = lint.Options{
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"onlyEquality\":true}]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue("yoda", config.value);

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.yoda.id));
}

test "supports configured yoda exceptRange option" {
    const source =
        \\if (0 <= age && age < 18) {}
        \\if (age >= 65 || 12 > age) {}
        \\if (0 < count) {}
    ;

    var options = lint.Options{
        .eqeqeq = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"exceptRange\":true}]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue("yoda", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.yoda.id));
}

test "autofix respects configured yoda exceptRange" {
    const source =
        \\if (0 <= age && age < 18) {}
        \\if (0 < count) {}
    ;
    const expected =
        \\if (0 <= age && age < 18) {}
        \\if (count > 0) {}
    ;

    var options = lint.Options{
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\",{\"exceptRange\":true}]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue("yoda", config.value);

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.yoda.id));
}

test "can disable yoda" {
    const source =
        \\if ("red" === color) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .yoda = false,
        .eqeqeq = false,
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.yoda.id));
}
