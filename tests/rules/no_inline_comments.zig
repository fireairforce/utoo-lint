const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-inline-comments for comments sharing a line with code" {
    const source =
        "const first = 1; // inline\n" ++
        "/* leading */ const second = 2;\n" ++
        "const third = 3; /* trailing */\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_inline_comments.id));
    try std.testing.expectEqualStrings(
        "Unexpected comment inline with code.",
        result.diagnostics[0].message,
    );
}

test "does not report no-inline-comments for standalone comments" {
    const source =
        "// line comment\n" ++
        "const first = 1;\n" ++
        "/* block comment */\n" ++
        "const second = 2;\n" ++
        "/* multi\n" ++
        " * line\n" ++
        " */\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_inline_comments.id));
}

test "can disable no-inline-comments" {
    const source = "const value = 1; // inline\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_inline_comments.id));
}
