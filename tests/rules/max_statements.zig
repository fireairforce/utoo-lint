const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports max-statements for functions with too many statements" {
    const source =
        \\function run() {
        \\  one();
        \\  two();
        \\  three();
        \\  four();
        \\  five();
        \\  six();
        \\  seven();
        \\  eight();
        \\  nine();
        \\  ten();
        \\  eleven();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_statements.id));
    try std.testing.expect(hasMessage(result, "Maximum allowed is 10."));
}

test "counts statements in nested blocks" {
    const source =
        \\function run() {
        \\  if (ready) {
        \\    one();
        \\    two();
        \\  }
        \\}
    ;

    var options = baseOptions();
    options.max_statements_max = 2;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_statements.id));
}

test "supports configured max-statements max and deprecated maximum" {
    const source =
        \\function run() {
        \\  one();
        \\  two();
        \\  three();
        \\}
    ;

    const max_config =
        \\["error", { "max": 2 }]
    ;
    var max_options = baseOptions();
    var max_parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, max_config, .{});
    defer max_parsed.deinit();
    try max_options.setByRuleConfigValue("max-statements", max_parsed.value);

    var max_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", max_options);
    defer max_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(max_result, lint.rules.max_statements.id));

    const maximum_config =
        \\["error", { "maximum": 3 }]
    ;
    var maximum_options = baseOptions();
    var maximum_parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, maximum_config, .{});
    defer maximum_parsed.deinit();
    try maximum_options.setByRuleConfigValue("max-statements", maximum_parsed.value);

    var maximum_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", maximum_options);
    defer maximum_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(maximum_result, lint.rules.max_statements.id));
}

test "supports max-statements ignoreTopLevelFunctions" {
    const single_source =
        \\function run() {
        \\  one();
        \\  two();
        \\  three();
        \\}
    ;

    var single_options = baseOptions();
    single_options.max_statements_max = 2;
    single_options.max_statements_ignore_top_level_functions = true;

    var single_result = try lint.lintSource(std.testing.allocator, single_source, "fixture.js", single_options);
    defer single_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(single_result, lint.rules.max_statements.id));

    const multiple_source =
        \\function first() {
        \\  one();
        \\  two();
        \\  three();
        \\}
        \\function second() {
        \\  one();
        \\  two();
        \\  three();
        \\}
    ;

    var multiple_result = try lint.lintSource(std.testing.allocator, multiple_source, "fixture.js", single_options);
    defer multiple_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(multiple_result, lint.rules.max_statements.id));
}

test "does not count static block statements in the enclosing function" {
    const source =
        \\function run() {
        \\  class Example {
        \\    static {
        \\      one();
        \\      two();
        \\      three();
        \\    }
        \\  }
        \\  done();
        \\}
    ;

    var options = baseOptions();
    options.max_statements_max = 2;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_statements.id));
}

test "can disable max-statements" {
    const source =
        \\function run() {
        \\  one();
        \\  two();
        \\  three();
        \\}
    ;

    var options = baseOptions();
    options.max_statements = false;
    options.max_statements_max = 2;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_statements.id));
}

fn baseOptions() lint.Options {
    return .{
        .curly = false,
        .max_depth = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_empty_function = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.max_statements.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
