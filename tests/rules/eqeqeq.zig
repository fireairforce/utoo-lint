const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports eqeqeq for loose equality operators" {
    const source =
        \\if (value == 1) { use(value); }
        \\if (value != 2) { use(value); }
        \\if (value == null) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.eqeqeq.id));
}

test "autofixes loose equality when strict equality preserves semantics" {
    const source =
        \\typeof value == "undefined";
        \\"left" != "right";
        \\2 == 3;
        \\`same` == "same";
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\typeof value === "undefined";
        \\"left" !== "right";
        \\2 === 3;
        \\`same` === "same";
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.eqeqeq.id));
}

test "keeps unsafe loose equality diagnostics unfixed and preserves comments" {
    const source =
        \\value == other;
        \\value != 1;
        \\value == null;
        \\typeof value /* marker == */ == "undefined";
        \\`dynamic ${value}` == `static`;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_eq_null = false,
        .no_undef = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\value == other;
        \\value != 1;
        \\value == null;
        \\typeof value /* marker == */ === "undefined";
        \\`dynamic ${value}` == `static`;
    , result.output);
    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result.result, lint.rules.eqeqeq.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.eqeqeq.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "supports configured eqeqeq allow-null style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"allow-null\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("eqeqeq", config.value);
    options.no_eq_null = false;
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\if (value == null) { use(value); }
        \\if (null != value) { use(value); }
        \\if (value == undefined) { use(value); }
        \\if (value == 1) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.eqeqeq.id));
}

test "supports configured eqeqeq smart style" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"smart\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("eqeqeq", config.value);
    options.no_eq_null = false;
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\if (value == null) { use(value); }
        \\if (typeof value == "undefined") { use(value); }
        \\if ("number" != typeof value) { use(value); }
        \\if (1 == 1) { use(value); }
        \\if (true != false) { use(value); }
        \\if ("text" == 1) { use(value); }
        \\if (value == 1) { use(value); }
        \\if (value != other) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.eqeqeq.id));
}
