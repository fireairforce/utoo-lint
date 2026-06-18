const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-unused-vars for unused variables and after-used parameters" {
    const source =
        \\const unused = 1;
        \\const used = 2;
        \\console.log(used);
        \\
        \\function demo(before: string, usedParam: string, after: string) {
        \\  console.log(usedParam);
        \\}
        \\demo("before", "used", "after");
        \\
        \\try {
        \\  demo("before", "used", "after");
        \\} catch (unusedError) {
        \\}
        \\
        \\type UnusedType = string;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unused_vars.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_unused_vars.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "ignores rest siblings for object destructuring" {
    const source =
        \\const data = { a: 1, b: 2 };
        \\const { a, ...rest } = data;
        \\console.log(rest);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "supports configured @typescript-eslint/no-unused-vars ignoreRestSiblings false" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignoreRestSiblings\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-unused-vars", config.value);
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\const data = { a: 1, b: 2 };
        \\const { a, ...rest } = data;
        \\console.log(rest);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "supports configured @typescript-eslint/no-unused-vars args none" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"args\":\"none\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-unused-vars", config.value);
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\function demo(before: string, used: string, after: string) {
        \\  console.log(used);
        \\}
        \\demo("before", "used", "after");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "supports configured @typescript-eslint/no-unused-vars argsIgnorePattern" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"args\":\"all\",\"argsIgnorePattern\":\"^ignored\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-unused-vars", config.value);
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\function demo(ignoredParam: string, unusedParam: string, usedParam: string) {
        \\  console.log(usedParam);
        \\}
        \\demo("ignored", "unused", "used");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "supports configured @typescript-eslint/no-unused-vars vars local" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"vars\":\"local\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-unused-vars", config.value);
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\type GlobalUnused = string;
        \\const globalUnused = 1;
        \\function demo() {
        \\  type LocalUnused = number;
        \\  const localUnused = 2;
        \\}
        \\demo();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "supports configured @typescript-eslint/no-unused-vars caughtErrors none" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"caughtErrors\":\"none\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-unused-vars", config.value);
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\try {
        \\  run();
        \\} catch (unusedError) {
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "supports configured @typescript-eslint/no-unused-vars caughtErrorsIgnorePattern" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"caughtErrors\":\"all\",\"caughtErrorsIgnorePattern\":\"^ignored\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-unused-vars", config.value);
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\try {
        \\  run();
        \\} catch (ignoredError) {
        \\}
        \\try {
        \\  run();
        \\} catch (unusedError) {
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
}

test "can disable @typescript-eslint/no-unused-vars and fall back to core rule" {
    const source =
        \\const unused = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unused_vars.id));
    try std.testing.expect(helpers.hasRule(result, lint.rules.no_unused_vars.id));
}
