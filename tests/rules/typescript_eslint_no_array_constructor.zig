const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-array-constructor for generic Array constructors" {
    const source =
        \\const a = Array();
        \\const b = new Array();
        \\const c = Array(1, 2);
        \\const d = new Array("a", "b");
        \\const e = Array?.();
        \\const f = Array?.(1, 2);
        \\function local(Array: (...args: unknown[]) => unknown) {
        \\  const g = Array();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.typescript_eslint_no_array_constructor.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_array_constructor.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_array_constructor.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/no-array-constructor for single arguments or type arguments" {
    const source =
        \\const a = Array(length);
        \\const b = new Array(10);
        \\const c = Array(...items);
        \\const d = Array<string>();
        \\const e = new Array<string>();
        \\const f = Array?.(length);
        \\const g = Array?.(...items);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_array_constructor.id));
}

test "autofixes @typescript-eslint/no-array-constructor diagnostics" {
    const source =
        \\const a = Array();
        \\const b = new Array(1, 2);
        \\Array?.();
    ;
    const expected =
        \\const a = [];
        \\const b = [1, 2];
        \\[];
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.typescript_eslint_no_array_constructor.id));
}

test "typescript autofix preserves ASI and constructor header comments" {
    const source =
        \\previous()
        \\Array()
        \\new /* keep */ Array(1, 2)
    ;
    const expected =
        \\previous()
        \\;[]
        \\new /* keep */ Array(1, 2)
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.ts", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result.result, lint.rules.typescript_eslint_no_array_constructor.id));
}

test "can disable @typescript-eslint/no-array-constructor and fall back to core rule" {
    const source =
        \\const a = Array();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_array_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_array_constructor.id));
    try std.testing.expect(helpers.hasRule(result, lint.rules.no_array_constructor.id));
}
