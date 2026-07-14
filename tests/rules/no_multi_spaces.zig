const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-multi-spaces for multiple spaces outside indentation" {
    const source =
        "const first =  1;\n" ++
        "if (foo  === bar) {}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_multi_spaces.id));
    try std.testing.expectEqualStrings(
        "Multiple spaces found before.",
        result.diagnostics[0].message,
    );
}

test "reports no-multi-spaces before end-of-line comments" {
    const source = "const value = 1;  // comment\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_multi_spaces.id));
}

test "allows no-multi-spaces before end-of-line comments when configured" {
    const source =
        "const value =  1;\n" ++
        "const line = 1;  // comment\n" ++
        "const block = 1;  /* comment */\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_multi_spaces_ignore_eol_comments = .yes,
        .no_inline_comments = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_multi_spaces.id));
}

test "does not report no-multi-spaces for indentation or inside literals and comments" {
    const source =
        "  const text = \"hello  world\";\n" ++
        "const template = `hello  world`;\n" ++
        "// comment  with spaces\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_multi_spaces.id));
}

test "does not report no-multi-spaces for object property alignment" {
    const source =
        "const obj = {\n" ++
        "  a  : 1,\n" ++
        "  bb:  2,\n" ++
        "  [key  ]: 3,\n" ++
        "  async  method  () {},\n" ++
        "};\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_multi_spaces.id));
}

test "supports configured no-multi-spaces Property exception" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"exceptions\":{\"Property\":false}}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("no-multi-spaces", config.value);

    const source =
        "const obj = {\n" ++
        "  a  : 1,\n" ++
        "  bb:  2,\n" ++
        "};\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_multi_spaces.id));
}

test "supports configured no-multi-spaces expression declaration and import exceptions" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"exceptions\":{\"BinaryExpression\":true,\"VariableDeclarator\":true,\"ImportDeclaration\":true}}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("no-multi-spaces", config.value);

    const source =
        "import mod          from \"mod\";\n" ++
        "const aligned      = 1;\n" ++
        "const product = 1  *  2;\n" ++
        "reported(  1);\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_multi_spaces.id));
}

test "still reports no-multi-spaces inside object property values" {
    const source =
        "const obj = {\n" ++
        "  a: fn(  1),\n" ++
        "  b: 1 +  2,\n" ++
        "};\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_multi_spaces.id));
}

test "can disable no-multi-spaces" {
    const source = "const value =  1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_multi_spaces = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_multi_spaces.id));
}

test "autofixes reported runs of multiple spaces" {
    const source =
        "const first =  1;\n" ++
        "if (foo   === bar) {}\n" ++
        "const second = 2;  // comment\n";
    const expected =
        "const first = 1;\n" ++
        "if (foo === bar) {}\n" ++
        "const second = 2; // comment\n";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .no_inline_comments = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_multi_spaces.id));
}
