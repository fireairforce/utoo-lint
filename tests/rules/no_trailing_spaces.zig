const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-trailing-spaces for line endings with spaces or tabs" {
    const source =
        "const first = 1; \n" ++
        "const second = 2;\t\n" ++
        "  \n" ++
        "const third = 3;\r\n" ++
        "const fourth = 4;\t\r\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_trailing_spaces.id));
}

test "does not report no-trailing-spaces for clean lines" {
    const source =
        "const first = 1;\n" ++
        "\n" ++
        "// comment\n" ++
        "const second = 2;\r\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_trailing_spaces.id));
}

test "supports configured no-trailing-spaces blank line and comment ignores" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"skipBlankLines\":true,\"ignoreComments\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("no-trailing-spaces", config.value);

    const source =
        "const value = 1; \n" ++
        "   \n" ++
        "// comment   \n" ++
        "/* start   \n" ++
        " * middle\t\n" ++
        " */   \n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_trailing_spaces.id));
}

test "can disable no-trailing-spaces" {
    const source = "const value = 1; \n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_trailing_spaces = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_trailing_spaces.id));
}
