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
