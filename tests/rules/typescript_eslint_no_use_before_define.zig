const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-use-before-define for classes and variables but not functions" {
    const source =
        \\f();
        \\function f() {}
        \\
        \\new C();
        \\class C {}
        \\
        \\a;
        \\let a = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_use_before_define.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_use_before_define.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_use_before_define.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/no-use-before-define for type references" {
    const source =
        \\let value: Later;
        \\type Later = string;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_use_before_define.id));
}

test "can disable @typescript-eslint/no-use-before-define and fall back to core rule" {
    const source =
        \\f();
        \\function f() {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_use_before_define = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_use_before_define.id));
    try std.testing.expect(helpers.hasRule(result, lint.rules.no_use_before_define.id));
}
