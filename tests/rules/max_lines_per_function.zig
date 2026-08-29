const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports functions with too many lines" {
    const source =
        \\function tooMany() {
        \\  const one = 1;
        \\  return one;
        \\}
    ;

    var options = baseOptions();
    options.max_lines_per_function_max = 3;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_lines_per_function.id));
    try std.testing.expect(hasMessage(result, "Function has too many lines (4). Maximum allowed is 3."));
}

test "checks arrow functions and skips short functions" {
    const source =
        \\const ok = () => 1;
        \\const tooMany = () => {
        \\  const one = 1;
        \\  return one;
        \\};
    ;

    var options = baseOptions();
    options.max_lines_per_function_max = 3;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_lines_per_function.id));
}

test "supports skipBlankLines and skipComments" {
    const source =
        \\function counted() {
        \\  // comment
        \\
        \\  return value;
        \\}
    ;

    var strict_options = baseOptions();
    strict_options.max_lines_per_function_max = 3;

    var strict_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", strict_options);
    defer strict_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(strict_result, lint.rules.max_lines_per_function.id));

    var skipped_options = strict_options;
    skipped_options.max_lines_per_function_skip_blank_lines = true;
    skipped_options.max_lines_per_function_skip_comments = true;

    var skipped_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", skipped_options);
    defer skipped_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(skipped_result, lint.rules.max_lines_per_function.id));
}

test "skipComments handles multiline comments without skipping inline code" {
    const source =
        \\function counted() {
        \\  /* first
        \\   * second
        \\   */
        \\  const value = 1; // inline comment
        \\  return value;
        \\}
    ;

    var options = baseOptions();
    options.max_lines_per_function_max = 3;
    options.max_lines_per_function_skip_comments = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_lines_per_function.id));
    try std.testing.expect(hasMessage(result, "Function has too many lines (4). Maximum allowed is 3."));
}

test "skips IIFEs unless configured" {
    const source =
        \\(function () {
        \\  const one = 1;
        \\  return one;
        \\})();
    ;

    var skipped_options = baseOptions();
    skipped_options.max_lines_per_function_max = 3;

    var skipped_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", skipped_options);
    defer skipped_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(skipped_result, lint.rules.max_lines_per_function.id));

    var counted_options = skipped_options;
    counted_options.max_lines_per_function_iifes = true;

    var counted_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", counted_options);
    defer counted_result.deinit(std.testing.allocator);
    try std.testing.expect(helpers.hasRule(counted_result, lint.rules.max_lines_per_function.id));
}

test "can disable max-lines-per-function" {
    const source =
        \\function tooMany() {
        \\  const one = 1;
        \\  return one;
        \\}
    ;

    var options = baseOptions();
    options.max_lines_per_function = false;
    options.max_lines_per_function_max = 1;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_lines_per_function.id));
}

fn baseOptions() lint.Options {
    return .{
        .max_lines_per_function = true,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.max_lines_per_function.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
