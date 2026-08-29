const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-mixed-spaces-and-tabs for mixed indentation" {
    const source =
        "if (ok) {\n" ++
        " \tfoo();\n" ++
        "\t bar();\n" ++
        "  baz();\n" ++
        "}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_tabs = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_mixed_spaces_and_tabs.id));
}

test "does not report no-mixed-spaces-and-tabs for pure spaces or tabs" {
    const source =
        "if (ok) {\n" ++
        "  foo();\n" ++
        "\tbar();\n" ++
        "}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_tabs = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_mixed_spaces_and_tabs.id));
}

test "supports configured no-mixed-spaces-and-tabs smart tabs" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"smart-tabs\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_tabs = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("no-mixed-spaces-and-tabs", config.value);

    const source =
        "if (ok) {\n" ++
        "\t  alignedWithSpaces();\n" ++
        " \tbadIndent();\n" ++
        "}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_mixed_spaces_and_tabs.id));
}

test "ignores mixed indentation inside block comment continuation and template literals" {
    const source =
        "/* block\n" ++
        " \tcomment\n" ++
        "*/\n" ++
        "const text = `\n" ++
        " \tinside\n" ++
        "`;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_tabs = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_mixed_spaces_and_tabs.id));
}

test "resumes reporting after ignored block comments and template literals" {
    const source =
        "/* block\n" ++
        " \tcomment\n" ++
        "*/\n" ++
        "const text = `\n" ++
        " \tinside\n" ++
        "`;\n" ++
        " \treported();\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_mixed_spaces_and_tabs = true,
        .no_tabs = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_mixed_spaces_and_tabs.id));
}

test "can disable no-mixed-spaces-and-tabs" {
    const source = "if (ok) {\n \tfoo();\n}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_mixed_spaces_and_tabs = false,
        .no_tabs = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_mixed_spaces_and_tabs.id));
}
