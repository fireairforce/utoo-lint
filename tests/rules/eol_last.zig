const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports eol-last when a non-empty file does not end with a newline" {
    const source = "const value = 1;";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.eol_last.id));
    try std.testing.expectEqualStrings(
        "Newline required at end of file but not found.",
        result.diagnostics[0].message,
    );
}

test "does not report eol-last when source ends with a newline" {
    const source = "const value = 1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.eol_last.id));
}

test "does not report eol-last for empty source" {
    var result = try lint.lintSource(std.testing.allocator, "", "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.eol_last.id));
}

test "supports configured eol-last never" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("eol-last", config.value);

    var result = try lint.lintSource(std.testing.allocator, "const value = 1;\n", "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.eol_last.id));
    try std.testing.expectEqualStrings(
        "Newline not allowed at end of file.",
        result.diagnostics[0].message,
    );
}

test "supports configured eol-last unix alias" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"unix\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("eol-last", config.value);

    var result = try lint.lintSource(std.testing.allocator, "const value = 1;", "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.eol_last.id));
}

test "can disable eol-last" {
    const source = "const value = 1;";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.eol_last.id));
}
