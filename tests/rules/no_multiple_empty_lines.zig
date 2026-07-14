const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-multiple-empty-lines after more than two consecutive blank lines" {
    const source =
        "const first = 1;\n" ++
        "\n" ++
        "\n" ++
        "\n" ++
        "const second = 2;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_multiple_empty_lines.id));
    try std.testing.expectEqualStrings(
        "More than 2 blank lines not allowed.",
        result.diagnostics[0].message,
    );
}

test "counts whitespace-only lines as empty lines" {
    const source =
        "const first = 1;\n" ++
        " \n" ++
        "\t\n" ++
        "\n" ++
        "\n" ++
        "const second = 2;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_trailing_spaces = false,
        .no_tabs = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_multiple_empty_lines.id));
}

test "does not report no-multiple-empty-lines for two blank lines" {
    const source =
        "const first = 1;\n" ++
        "\n" ++
        "\n" ++
        "const second = 2;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_multiple_empty_lines.id));
}

test "supports no-multiple-empty-lines max option" {
    const source =
        "const first = 1;\n" ++
        "\n" ++
        "\n" ++
        "const second = 2;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_multiple_empty_lines_max = 1,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_multiple_empty_lines.id));
    try std.testing.expectEqualStrings(
        "More than 1 blank lines not allowed.",
        result.diagnostics[0].message,
    );
}

test "supports no-multiple-empty-lines maxBOF option" {
    const source =
        "\n" ++
        "const first = 1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_multiple_empty_lines_max_bof = 0,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_multiple_empty_lines.id));
    try std.testing.expectEqualStrings(
        "More than 0 blank lines not allowed.",
        result.diagnostics[0].message,
    );
}

test "supports no-multiple-empty-lines maxEOF option" {
    const source =
        "const first = 1;\n" ++
        "\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_multiple_empty_lines_max_eof = 0,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_multiple_empty_lines.id));
    try std.testing.expectEqualStrings(
        "More than 0 blank lines not allowed.",
        result.diagnostics[0].message,
    );
}

test "does not count a single final newline as an empty EOF line" {
    const source = "const first = 1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_multiple_empty_lines_max_eof = 0,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_multiple_empty_lines.id));
}

test "can disable no-multiple-empty-lines" {
    const source = "const first = 1;\n\n\n\nconst second = 2;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_multiple_empty_lines = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_multiple_empty_lines.id));
}

test "autofixes excess blank lines between statements" {
    const source =
        "const first = 1;\n" ++
        "\n" ++
        "\n" ++
        "\n" ++
        "\n" ++
        "const second = 2;\n";
    const expected =
        "const first = 1;\n" ++
        "\n" ++
        "\n" ++
        "const second = 2;\n";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_multiple_empty_lines.id));
}

test "autofixes CRLF blank lines at the beginning and end of a file" {
    const source =
        "\r\n" ++
        "\r\n" ++
        "const value = 1;\r\n" ++
        "\r\n" ++
        "\r\n";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .linebreak_style_style = .windows,
        .no_multiple_empty_lines_max_bof = 0,
        .no_multiple_empty_lines_max_eof = 0,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("const value = 1;\r\n", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_multiple_empty_lines.id));
}
