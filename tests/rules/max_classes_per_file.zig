const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports max-classes-per-file for too many class declarations" {
    const source =
        \\class One {}
        \\class Two {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_classes_per_file.id));
    try std.testing.expect(hasMessage(result, "Maximum allowed is 1."));
}

test "allows configured max-classes-per-file maximum" {
    const source =
        \\class One {}
        \\class Two {}
    ;

    var options = baseOptions();
    options.max_classes_per_file_max = 2;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_classes_per_file.id));
}

test "supports max-classes-per-file config object" {
    const source =
        \\class One {}
        \\class Two {}
        \\const Three = class {};
    ;

    const config =
        \\["error", { "max": 1, "ignoreExpressions": true }]
    ;
    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue("max-classes-per-file", parsed.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_classes_per_file.id));
}

test "can ignore class expressions" {
    const source =
        \\class One {}
        \\const Two = class {};
    ;

    var options = baseOptions();
    options.max_classes_per_file_ignore_expressions = true;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_classes_per_file.id));
}

test "can disable max-classes-per-file" {
    const source =
        \\class One {}
        \\class Two {}
    ;

    var options = baseOptions();
    options.max_classes_per_file = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_classes_per_file.id));
}

fn baseOptions() lint.Options {
    return .{
        .max_statements = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.max_classes_per_file.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
