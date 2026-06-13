const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-use-before-define for references before declarations" {
    const source =
        \\f();
        \\function f() {}
        \\
        \\new C();
        \\class C {}
        \\
        \\a;
        \\var a = 1;
        \\
        \\var b = b;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_no_use_before_define = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_use_before_define.id));
}

test "does not report no-use-before-define for references after declarations" {
    const source =
        \\function f() {}
        \\f();
        \\
        \\class C {}
        \\new C();
        \\
        \\var a = 1;
        \\a;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_no_use_before_define = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_use_before_define.id));
}

test "reports no-use-before-define for repeated initializer self references" {
    const source =
        \\var a = a;
        \\var a = a;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_redeclare = false,
        .no_unused_vars = false,
        .typescript_eslint_no_use_before_define = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_use_before_define.id));
}

test "can disable no-use-before-define" {
    const source =
        \\a;
        \\var a = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_use_before_define = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .typescript_eslint_no_use_before_define = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_use_before_define.id));
}
