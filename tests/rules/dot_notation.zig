const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports dot-notation for computed string properties that can use dot access" {
    const source =
        \\object["property"];
        \\object["_private"];
        \\object["$value"];
        \\object["property1"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.dot_notation.id));
    try std.testing.expectEqualStrings(
        "['property'] is better written in dot notation.",
        result.diagnostics[0].message,
    );
}

test "does not report dot-notation when bracket access is required" {
    const source =
        \\object["not-valid"];
        \\object["123"];
        \\object[""];
        \\object[property];
        \\object[call()];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.dot_notation.id));
}

test "can disable dot-notation" {
    const source =
        \\object["property"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.dot_notation.id));
}
