const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-redeclare for TypeScript redeclarations" {
    const source =
        \\let value = 1;
        \\let value = 2;
        \\type Box = {};
        \\type Box = {};
        \\type Shape = {};
        \\interface Shape {}
        \\declare const ambient: string;
        \\declare const ambient: string;
        \\enum Direction {}
        \\enum Direction {}
        \\function duplicate() { return 1; }
        \\function duplicate() { return 2; }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_empty_block_statements = false,
        .typescript_eslint_consistent_type_definitions = false,
        .typescript_eslint_no_empty_function = false,
        .typescript_eslint_no_empty_interface = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.typescript_eslint_no_redeclare.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_redeclare.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_redeclare.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "allows @typescript-eslint/no-redeclare TypeScript declaration merging" {
    const source =
        \\interface Box {}
        \\interface Box {}
        \\class Model {}
        \\interface Model {}
        \\enum Direction {}
        \\namespace Direction {}
        \\namespace Factory {}
        \\function Factory() {}
        \\function overload(value: string): void;
        \\function overload(value: number): void;
        \\function overload(value: string | number): void {
        \\  value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_empty_block_statements = false,
        .typescript_eslint_no_empty_function = false,
        .typescript_eslint_no_empty_interface = false,
        .typescript_eslint_no_namespace = false,
        .typescript_eslint_unified_signatures = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_redeclare.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_redeclare.id));
}

test "can disable @typescript-eslint/no-redeclare and fall back to no-redeclare" {
    const source =
        \\let value = 1;
        \\let value = 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_redeclare = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_redeclare.id));
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_redeclare.id));
}
