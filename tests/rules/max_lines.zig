const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports max-lines for files with too many lines" {
    const source =
        \\const one = 1;
        \\const two = 2;
        \\const three = 3;
    ;

    var options = baseOptions();
    options.max_lines_max = 2;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_lines.id));
    try std.testing.expect(hasMessage(result, "File has too many lines (3). Maximum allowed is 2."));
}

test "does not count the final trailing linebreak as an extra line" {
    const source = "const one = 1;\n";

    var options = baseOptions();
    options.max_lines_max = 1;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_lines.id));
}

test "supports max-lines skipBlankLines" {
    const source =
        \\const one = 1;
        \\
        \\const two = 2;
    ;

    var strict_options = baseOptions();
    strict_options.max_lines_max = 2;

    var strict_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", strict_options);
    defer strict_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(strict_result, lint.rules.max_lines.id));

    var skipped_options = strict_options;
    skipped_options.max_lines_skip_blank_lines = true;

    var skipped_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", skipped_options);
    defer skipped_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(skipped_result, lint.rules.max_lines.id));
}

test "supports max-lines skipComments without skipping inline comments" {
    const source =
        \\// header
        \\const one = 1; // inline
        \\/* block
        \\ * comment
        \\ */
        \\const two = 2;
    ;

    var skipped_options = baseOptions();
    skipped_options.max_lines_max = 2;
    skipped_options.max_lines_skip_comments = true;

    var skipped_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", skipped_options);
    defer skipped_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(skipped_result, lint.rules.max_lines.id));

    var strict_options = skipped_options;
    strict_options.max_lines_max = 1;

    var strict_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", strict_options);
    defer strict_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(strict_result, lint.rules.max_lines.id));
}

test "supports max-lines config object" {
    const source =
        \\// header
        \\const one = 1;
        \\
        \\const two = 2;
    ;

    const config =
        \\["error", { "max": 2, "skipBlankLines": true, "skipComments": true }]
    ;

    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue("max-lines", parsed.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_lines.id));
}

test "can disable max-lines" {
    const source =
        \\const one = 1;
        \\const two = 2;
    ;

    var options = baseOptions();
    options.max_lines = false;
    options.max_lines_max = 1;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_lines.id));
}

fn baseOptions() lint.Options {
    return .{
        .max_lines = true,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.max_lines.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
