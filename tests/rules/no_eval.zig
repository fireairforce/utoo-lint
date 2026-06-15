const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-eval for direct indirect and global eval calls" {
    const source =
        \\eval("code");
        \\(eval)("code");
        \\(0, eval)("code");
        \\window.eval("code");
        \\globalThis["eval"]("code");
        \\globalThis[`eval`]("code");
        \\global.eval("code");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_comma_operator = false,
        .no_sequences = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_eval.id));
}

test "does not report no-eval for non-global eval members" {
    const source =
        \\const object = { eval() {} };
        \\object.eval("code");
        \\object["eval"]("code");
        \\object[`eval`]("code");
        \\globalThis[`ev${suffix}`]("code");
        \\const window = sandbox;
        \\window.eval("code");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_eval.id));
}

test "can disable no-eval" {
    const source =
        \\eval("code");
        \\window.eval("code");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_eval = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_eval.id));
}
