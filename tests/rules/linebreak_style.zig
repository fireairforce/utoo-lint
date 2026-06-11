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
