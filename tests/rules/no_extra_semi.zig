const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-extra-semi for unnecessary empty statements" {
    const source =
        \\const value = 1;;
        \\function run() {}
        \\;
        \\class Example { ; method() {} ; field; }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_extra_semi = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_extra_semi.id));
}

test "does not report no-extra-semi for empty statement bodies" {
    const source =
        \\while (ready);
        \\for (; ready; );
        \\if (ready); else ;
        \\label: ;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_labels = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_extra_semi = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_semi.id));
}

test "can disable no-extra-semi" {
    const source =
        \\const value = 1;;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_extra_semi = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_extra_semi = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_semi.id));
}
