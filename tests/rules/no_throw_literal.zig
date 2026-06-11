const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-throw-literal for literal throw arguments" {
    const source =
        \\throw "error";
        \\throw 1;
        \\throw true;
        \\throw null;
        \\throw undefined;
        \\throw `error`;
        \\throw "prefix " + error;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_throw_literal.id));
}

test "does not report no-throw-literal for error objects or references" {
    const source =
        \\throw new Error("boom");
        \\throw error;
        \\throw getError();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_throw_literal.id));
}

test "can disable no-throw-literal" {
    const source =
        \\throw "error";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_throw_literal = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_throw_literal.id));
}
