const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-irregular-whitespace outside strings" {
    const nbsp = "\xC2\xA0";
    const source =
        "const" ++ nbsp ++ "first = 1;\n" ++
        "//" ++ nbsp ++ "comment\n" ++
        "const second = 2;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_irregular_whitespace.id));
    try std.testing.expectEqualStrings(
        "Irregular whitespace not allowed.",
        result.diagnostics[0].message,
    );
}

test "does not report no-irregular-whitespace inside strings by default" {
    const nbsp = "\xC2\xA0";
    const source = "const value = \"hello" ++ nbsp ++ "world\";\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_irregular_whitespace.id));
}

test "reports no-irregular-whitespace inside strings when configured" {
    const nbsp = "\xC2\xA0";
    const source = "const value = \"hello" ++ nbsp ++ "world\";\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_irregular_whitespace_skip_strings = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_irregular_whitespace.id));
}

test "reports no-irregular-whitespace inside template literals" {
    const nbsp = "\xC2\xA0";
    const source = "const value = `hello" ++ nbsp ++ "world`;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_irregular_whitespace.id));
}

test "skips configured no-irregular-whitespace syntax spans" {
    const nbsp = "\xC2\xA0";
    const source =
        "// comment" ++ nbsp ++ "\n" ++
        "const pattern = /hello" ++ nbsp ++ "world/;\n" ++
        "const message = `hello" ++ nbsp ++ "world`;\n" ++
        "const element = <div>hello" ++ nbsp ++ "world</div>;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_irregular_whitespace_skip_comments = true,
        .no_irregular_whitespace_skip_reg_exps = true,
        .no_irregular_whitespace_skip_templates = true,
        .no_irregular_whitespace_skip_jsx_text = true,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_irregular_whitespace.id));
}

test "can disable no-irregular-whitespace" {
    const source = "const\xC2\xA0value = 1;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_irregular_whitespace = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_irregular_whitespace.id));
}
