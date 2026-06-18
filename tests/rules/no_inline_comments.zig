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

test "supports no-inline-comments ignorePattern option" {
    const source =
        "const first = 1; // eslint-disable-line no-console\n" ++
        "/* istanbul ignore next */ const second = 2;\n" ++
        "const third = 3; // regular inline\n";

    var options = lint.Options{
        .capitalized_comments = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.no_inline_comments_ignore_pattern.set("eslint-disable|istanbul ignore");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_inline_comments.id));
}

test "supports no-inline-comments regex-like ignorePattern syntax" {
    const source =
        "import value from './chunk'; /* webpackChunkName: \"admin\" */\n" ++
        "const other = 1; /* regular inline */\n";

    var options = lint.Options{
        .capitalized_comments = false,
        .import_first = false,
        .import_newline_after_import = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.no_inline_comments_ignore_pattern.set("webpackChunkName:\\s.+");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_inline_comments.id));
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
