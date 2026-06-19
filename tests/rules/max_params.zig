const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports max-params for functions with too many parameters" {
    const source =
        \\function foo(a, b, c, d) {
        \\  return a;
        \\}
        \\const bar = (a, b, c, d) => a;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.max_params.id));
    try std.testing.expect(hasMessage(result, "Maximum allowed is 3."));
}

test "allows max-params at or below the configured maximum" {
    const source =
        \\function foo(a, b, c) {
        \\  return a;
        \\}
        \\const bar = (a, b, c) => a;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_params.id));
}

test "supports configured max-params maximum and rest parameters" {
    const source =
        \\function foo(a, b, ...rest) {
        \\  return rest;
        \\}
        \\const bar = (a, b, c) => c;
    ;

    var options = baseOptions();
    options.max_params_max = 2;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.max_params.id));
}

test "supports max-params countThis modes" {
    const source =
        \\function hasNoThis(this: void, first: string, second: string) {
        \\  return first;
        \\}
        \\function hasThis(this: unknown, first: string, second: string) {
        \\  return first;
        \\}
    ;

    var default_options = baseOptions();
    default_options.max_params_max = 2;
    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", default_options);
    defer default_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.max_params.id));

    var always_options = baseOptions();
    always_options.max_params_max = 2;
    always_options.max_params_count_this = .always;
    var always_result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", always_options);
    defer always_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(always_result, lint.rules.max_params.id));

    var never_options = baseOptions();
    never_options.max_params_max = 2;
    never_options.max_params_count_this = .never;
    var never_result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", never_options);
    defer never_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(never_result, lint.rules.max_params.id));
}

test "can disable max-params" {
    const source =
        \\function foo(a, b, c, d) {
        \\  return a;
        \\}
    ;

    var options = baseOptions();
    options.max_params = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_params.id));
}

fn baseOptions() lint.Options {
    return .{
        .consistent_return = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_empty_function = false,
        .typescript_eslint_no_invalid_void_type = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.max_params.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
