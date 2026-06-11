const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-octal-escape for octal string escape sequences" {
    const source =
        \\const first = "\251";
        \\const second = "\07";
        \\const third = "\00";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_octal_escape.id));
}

test "does not report no-octal-escape for null or escaped backslash sequences" {
    const source =
        \\const nul = "\0";
        \\const escapedBackslash = "\\1";
        \\const hex = "\xA9";
        \\const unicode = "\u00A9";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_octal_escape.id));
}

test "can disable no-octal-escape" {
    const source =
        \\const value = "\251";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_octal_escape = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_octal_escape.id));
}
