const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/unified-signatures for unionable overloads" {
    const source =
        \\function f(value: string): void;
        \\function f(value: number): void;
        \\interface Shape {
        \\  method(value: "a"): void;
        \\  method(value: "b"): void;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_unified_signatures.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_unified_signatures.id)) {
            try std.testing.expectEqual(lint.Severity.warning, diagnostic.severity);
        }
    }
}

test "reports @typescript-eslint/unified-signatures for optional trailing parameters" {
    const source =
        \\interface Shape {
        \\  method(value: string): void;
        \\  method(value: string, extra: number): void;
        \\}
        \\interface ReverseShape {
        \\  method(value: string, extra: number): void;
        \\  method(value: string): void;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_unified_signatures.id));
}

test "allows @typescript-eslint/unified-signatures non-equivalent overloads" {
    const source =
        \\function f(value: string): string;
        \\function f(value: number): number;
        \\interface Shape {
        \\  method(value: string): void;
        \\  method(value: string, extra: number, other: boolean): void;
        \\  rest(value: string): void;
        \\  rest(...value: string[]): void;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_unified_signatures.id));
}

test "can disable @typescript-eslint/unified-signatures" {
    const source =
        \\interface Shape {
        \\  method(value: string): void;
        \\  method(value: number): void;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_unified_signatures = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_unified_signatures.id));
}
