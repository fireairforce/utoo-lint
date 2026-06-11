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
