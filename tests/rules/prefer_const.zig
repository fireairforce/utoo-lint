const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-const for initialized let declarations that are never reassigned" {
    const source =
        \\let a = 1;
        \\let { b } = obj;
        \\let [c] = list;
        \\for (let key in obj) {
        \\  console.log(key);
        \\}
        \\for (let value of list) {
        \\  console.log(value);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.prefer_const.id));
}

test "does not report prefer-const for reassigned let bindings or read-before-assign declarations by default" {
    const source =
        \\let a = 1;
        \\a = 2;
        \\let b = 1;
        \\b++;
        \\let c;
        \\console.log(c);
        \\c = 1;
        \\for (let key in obj) {
        \\  key = "other";
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_const.id));
}

test "supports configured prefer-const ignoreReadBeforeAssign false" {
    const source =
        \\let assignedOnce;
        \\assignedOnce = 1;
        \\console.log(assignedOnce);
        \\let readBefore;
        \\console.log(readBefore);
        \\readBefore = 1;
        \\let reassigned;
        \\reassigned = 1;
        \\reassigned = 2;
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer default_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.prefer_const.id));

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreReadBeforeAssign\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("prefer-const", config.value);
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    var configured_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer configured_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(configured_result, lint.rules.prefer_const.id));
}

test "reports prefer-const for destructuring any by default" {
    const source =
        \\let { a, b } = obj;
        \\b = 2;
        \\let [c, d] = list;
        \\d++;
        \\for (let [e, f] of entries) {
        \\  f = 2;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.prefer_const.id));
}

test "reports prefer-const for destructuring only when all bindings qualify in all mode" {
    const source =
        \\let { a, b } = obj;
        \\b = 2;
        \\let [c, d] = list;
        \\let { e: { f }, ...rest } = other;
        \\rest = {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .prefer_const_destructuring = .all,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.prefer_const.id));
}

test "uses configured prefer-const destructuring all mode" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"destructuring\":\"all\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("prefer-const", config.value);
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\let { a, b } = obj;
        \\b = 2;
        \\let [c, d] = list;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.prefer_const.id));
}

test "can disable prefer-const" {
    const source =
        \\let a = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .prefer_const = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_const.id));
}
