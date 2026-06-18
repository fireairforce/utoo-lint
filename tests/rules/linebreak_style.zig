const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports linebreak-style for CRLF line endings" {
    const source =
        "const first = 1;\r\n" ++
        "const second = 2;\r\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.linebreak_style.id));
    try std.testing.expectEqualStrings(
        "Expected linebreaks to be 'LF' but found 'CRLF'.",
        result.diagnostics[0].message,
    );
}

test "does not report linebreak-style for LF line endings" {
    const source =
        "const first = 1;\n" ++
        "const second = 2;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.linebreak_style.id));
}

test "supports configured linebreak-style windows" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"windows\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("linebreak-style", config.value);

    const source =
        "const first = 1;\n" ++
        "const second = 2;\r\n" ++
        "const third = 3;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.linebreak_style.id));
    try std.testing.expectEqualStrings(
        "Expected linebreaks to be 'CRLF' but found 'LF'.",
        result.diagnostics[0].message,
    );
}

test "can disable linebreak-style" {
    const source = "const value = 1;\r\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .linebreak_style = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.linebreak_style.id));
}
