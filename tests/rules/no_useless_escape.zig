const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-escape for unnecessary string and template escapes" {
    const source =
        \\const a = "\#";
        \\const b = '\"';
        \\const c = `\#`;
        \\const d = `\a ${value}`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_useless_escape.id));
}

test "reports no-useless-escape for unnecessary regular expression escapes" {
    const source =
        \\const a = /\#/;
        \\const b = /[\#]/;
        \\const c = /\-/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_useless_escape.id));
}

test "does not report no-useless-escape for necessary escapes" {
    const source =
        \\const a = "\"";
        \\const b = '\'';
        \\const c = "\\";
        \\const d = "\n\t\x20\u0020";
        \\const e = `\`${value}\${literal}`;
        \\const f = /\d+\.\w+\/x/;
        \\const g = /[\]\-\^]/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_escape.id));
}

test "can disable no-useless-escape" {
    const source =
        \\const a = "\#";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_escape = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_escape.id));
}
