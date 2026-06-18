const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports unicode-bom when source starts with a byte order mark" {
    const source = "\xEF\xBB\xBFconst value = 1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.unicode_bom.id));
    try std.testing.expectEqualStrings(
        "Unexpected Unicode BOM (Byte Order Mark).",
        result.diagnostics[0].message,
    );
}

test "does not report unicode-bom for ordinary source" {
    const source = "const value = 1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.unicode_bom.id));
}

test "supports configured unicode-bom always" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("unicode-bom", config.value);

    var result = try lint.lintSource(std.testing.allocator, "const value = 1;\n", "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.unicode_bom.id));
    try std.testing.expectEqualStrings(
        "Expected Unicode BOM (Byte Order Mark).",
        result.diagnostics[0].message,
    );
}

test "allows unicode-bom when configured always and BOM is present" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("unicode-bom", config.value);

    var result = try lint.lintSource(std.testing.allocator, "\xEF\xBB\xBFconst value = 1;\n", "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.unicode_bom.id));
}

test "can disable unicode-bom" {
    const source = "\xEF\xBB\xBFconst value = 1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .unicode_bom = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.unicode_bom.id));
}
