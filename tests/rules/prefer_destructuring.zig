const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-destructuring for object property variable declarators" {
    const source =
        \\const first = object.first;
        \\let second = object["second"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.prefer_destructuring.id));
}

test "autofixes simple object property variable declarators" {
    const source =
        \\const first = object.first;
        \\let second = source.second, third = other.third;
        \\const fromThis = this.fromThis;
        \\const value = (left || right).value;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .one_var = false,
        .prefer_const = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const {first} = object;
        \\let {second} = source, {third} = other;
        \\const {fromThis} = this;
        \\const {value} = (left || right);
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_destructuring.id));
}

test "autofix preserves object comments and refuses unsupported destructuring forms" {
    const source =
        \\const kept = (/* inside */ source).kept;
        \\const blocked /* binding */ = source.blocked;
        \\const gap = source /* member */ .gap;
        \\const computed = source["computed"];
        \\const alias = source.target;
        \\const wrapped = (source.wrapped);
        \\assigned = source.assigned;
        \\const item = list[0];
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .prefer_const = false,
        .prefer_destructuring_enforce_for_renamed_properties = true,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const {kept} = (/* inside */ source);
        \\const blocked /* binding */ = source.blocked;
        \\const gap = source /* member */ .gap;
        \\const computed = source["computed"];
        \\const alias = source.target;
        \\const wrapped = (source.wrapped);
        \\assigned = source.assigned;
        \\const item = list[0];
    , result.output);
    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result.result, lint.rules.prefer_destructuring.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.prefer_destructuring.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "reports prefer-destructuring for array index variable declarators" {
    const source =
        \\const first = array[0];
        \\let second = array["1"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.prefer_destructuring.id));
    try std.testing.expectEqualStrings("Use array destructuring.", result.diagnostics[0].message);
}

test "reports prefer-destructuring for assignment expressions" {
    const source =
        \\first = object.first;
        \\second = object["second"];
        \\item = array[0];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.prefer_destructuring.id));
    try std.testing.expectEqualStrings("Use object destructuring.", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("Use array destructuring.", result.diagnostics[2].message);
}

test "does not report prefer-destructuring for renamed dynamic or optional cases" {
    const source =
        \\const renamed = object.first;
        \\const value = object[key];
        \\const fractional = array[1.5];
        \\const maybe = object?.maybe;
        \\const maybeArray = array?.[0];
        \\renamed = object.target;
        \\value = object[key];
        \\fractional = array[1.5];
        \\maybe = object?.maybe;
        \\maybeArray = array?.[0];
        \\const { direct } = object;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_destructuring.id));
}

test "supports configured prefer-destructuring node type options" {
    const source =
        \\let first = object.first;
        \\let item = array[0];
        \\first = object.first;
        \\item = array[0];
    ;

    var options = lint.Options{
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_dot_notation = false,
    };
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"VariableDeclarator\":{\"array\":false,\"object\":true},\"AssignmentExpression\":{\"array\":true,\"object\":false}}]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue("prefer-destructuring", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.prefer_destructuring.id));
    try std.testing.expectEqualStrings("Use object destructuring.", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("Use array destructuring.", result.diagnostics[1].message);
}

test "supports top-level prefer-destructuring kind options" {
    const source =
        \\let first = object.first;
        \\let item = array[0];
        \\first = object.first;
        \\item = array[0];
    ;

    var options = lint.Options{
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_dot_notation = false,
    };
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"array\":false,\"object\":true}]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue("prefer-destructuring", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.prefer_destructuring.id));
    try std.testing.expectEqualStrings("Use object destructuring.", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("Use object destructuring.", result.diagnostics[1].message);
}

test "supports configured prefer-destructuring renamed property enforcement" {
    const source =
        \\let alias = object.first;
        \\alias = object.second;
        \\let item = array[0];
    ;

    var options = lint.Options{
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_dot_notation = false,
    };
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"object\":true,\"array\":false},{\"enforceForRenamedProperties\":true}]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue("prefer-destructuring", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.prefer_destructuring.id));
    try std.testing.expectEqualStrings("Use object destructuring.", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("Use object destructuring.", result.diagnostics[1].message);
}

test "can disable prefer-destructuring" {
    const source =
        \\const first = object.first;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .prefer_destructuring = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_destructuring.id));
}
