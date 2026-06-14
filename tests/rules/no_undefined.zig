const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-undefined for identifier references" {
    const source =
        \\const value = undefined;
        \\if (value === undefined) {}
        \\typeof undefined;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef_init = false,
        .eol_last = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_undefined.id));
    try std.testing.expectEqualStrings("Unexpected use of undefined.", result.diagnostics[0].message);
}

test "allows void 0 and typeof other identifiers" {
    const source =
        \\const value = void 0;
        \\if (typeof maybeMissing === "undefined") {}
        \\object.undefined;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .eol_last = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .no_void = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_undefined.id));
}

test "can disable no-undefined" {
    const source =
        \\const value = undefined;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef_init = false,
        .eol_last = false,
        .no_undefined = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_undefined.id));
}
