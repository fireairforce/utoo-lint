const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-octal for legacy octal numeric literals" {
    const source =
        \\const value = 071;
        \\const other = 0123;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_octal.id));
}

test "does not report no-octal for modern octal or decimal literals" {
    const source =
        \\const modern = 0o71;
        \\const upper = 0O71;
        \\const decimal = 71;
        \\const zero = 0;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_octal.id));
}

test "can disable no-octal" {
    const source =
        \\const value = 071;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_octal = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_octal.id));
}
