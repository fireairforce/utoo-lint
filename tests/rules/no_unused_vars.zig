const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unused-vars for unused declarations" {
    const source =
        \\const unused = 1;
        \\const used = 2;
        \\console.log(used);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.no_unused_vars.id));
}

test "reports no-unused-vars for unused catch parameters" {
    const source =
        \\try {
        \\  run();
        \\} catch (unusedError) {
        \\}
        \\try {
        \\  run();
        \\} catch (usedError) {
        \\  console.log(usedError);
        \\}
        \\try {
        \\  run();
        \\} catch {
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unused_vars.id));
}

test "supports configured no-unused-vars args all" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"args\":\"all\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-unused-vars", config.value);
    options.no_undef = false;
    options.typescript_eslint_no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\function demo(before, used, after) {
        \\  console.log(used);
        \\}
        \\demo(1, 2, 3);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unused_vars.id));
}

test "supports configured no-unused-vars vars local" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"vars\":\"local\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-unused-vars", config.value);
    options.no_undef = false;
    options.typescript_eslint_no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\const globalUnused = 1;
        \\function demo() {
        \\  const localUnused = 2;
        \\}
        \\demo();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unused_vars.id));
}

test "supports configured no-unused-vars caughtErrors none" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"caughtErrors\":\"none\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-unused-vars", config.value);
    options.no_undef = false;
    options.typescript_eslint_no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\try {
        \\  run();
        \\} catch (unusedError) {
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unused_vars.id));
}

test "supports configured no-unused-vars ignoreRestSiblings" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreRestSiblings\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-unused-vars", config.value);
    options.no_undef = false;
    options.typescript_eslint_no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\const data = { a: 1, b: 2 };
        \\const { a, ...rest } = data;
        \\console.log(rest);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unused_vars.id));
}
