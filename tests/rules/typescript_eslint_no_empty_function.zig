const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-empty-function for empty function bodies" {
    const source =
        \\function empty() {}
        \\const arrow = () => {};
        \\class Example {
        \\  method() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_no_empty_function.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty_function.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_empty_function.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/no-empty-function for comments or parameter properties" {
    const source =
        \\const documented = () => {
        \\  // intentionally empty
        \\};
        \\class Example {
        \\  constructor(public value: string) {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_empty_function.id));
}

test "supports configured @typescript-eslint/no-empty-function allow kinds" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"arrowFunctions\",\"methods\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-empty-function", config.value);
    options.no_empty_block_statements = false;
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\function empty() {}
        \\const arrow = () => {};
        \\class Example {
        \\  method() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_empty_function.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty_function.id));
}

test "supports configured @typescript-eslint/no-empty-function private and protected constructors" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"private-constructors\",\"protected-constructors\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-empty-function", config.value);
    options.no_empty_block_statements = false;
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\class Example {
        \\  private constructor() {}
        \\  protected constructor(value: string) {}
        \\  public static create() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_empty_function.id));
}

test "can disable @typescript-eslint/no-empty-function and fall back to core rule" {
    const source =
        \\function empty() {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_empty_function.id));
    try std.testing.expect(helpers.hasRule(result, lint.rules.no_empty_function.id));
}
