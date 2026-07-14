const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports dot-notation for computed string properties that can use dot access" {
    const source =
        \\object["property"];
        \\object[`template`];
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

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.dot_notation.id));
    try std.testing.expectEqualStrings(
        "['property'] is better written in dot notation.",
        result.diagnostics[0].message,
    );
}

test "does not report dot-notation when bracket access is required" {
    const source =
        \\const suffix = "erty";
        \\object["not-valid"];
        \\object[`not-valid`];
        \\object["123"];
        \\object[""];
        \\object[property];
        \\object[`prop${suffix}`];
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

test "supports configured dot-notation allowPattern option" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowPattern\":\"^[a-z]+(_[a-z]+)+$\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("dot-notation", config.value);

    const source =
        \\data["foo_bar"];
        \\data["foo_bar_baz"];
        \\data["fooBar"];
        \\data["foo_bar2"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.dot_notation.id));
}

test "supports common dot-notation allowPattern forms" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowPattern\":\"^private_|_id$\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("dot-notation", config.value);

    const source =
        \\data["private_name"];
        \\data["user_id"];
        \\data["publicName"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.dot_notation.id));
}

test "autofixes computed properties without changing token boundaries" {
    const source =
        \\object["property"];
        \\object[`template`];
        \\object?.["optional"];
        \\1["toString"];
        \\object["property"]in other;
    ;
    const expected =
        \\object.property;
        \\object.template;
        \\object?.optional;
        \\1 .toString;
        \\object.property in other;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.dot_notation.id));
}

test "does not autofix computed properties when comments would be discarded" {
    const source =
        \\object[/* keep */ "property"];
        \\object["property" /* keep */];
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result.result, lint.rules.dot_notation.id));
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
