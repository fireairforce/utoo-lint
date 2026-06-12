const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-array-constructor for generic Array constructors" {
    const source =
        \\const a = Array();
        \\const b = new Array();
        \\const c = Array(1, 2);
        \\const d = new Array("a", "b");
        \\function local(Array: (...args: unknown[]) => unknown) {
        \\  const e = Array();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.typescript_eslint_no_array_constructor.id));
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
        \\const f = Array?.();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_array_constructor.id));
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
