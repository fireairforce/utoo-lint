const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/adjacent-overload-signatures for separated function overloads" {
    const source =
        \\function parse(value: string): string;
        \\function other(value: string): string;
        \\function parse(value: number): number;
        \\function parse(value: string | number): string | number {
        \\  return value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_adjacent_overload_signatures.id));
}

test "reports @typescript-eslint/adjacent-overload-signatures for separated class and interface members" {
    const source =
        \\class Example {
        \\  method(value: string): string;
        \\  other(): void {}
        \\  method(value: number): number;
        \\  method(value: string | number): string | number {
        \\    return value;
        \\  }
        \\}
        \\interface Contract {
        \\  call(value: string): string;
        \\  other(): void;
        \\  call(value: number): number;
        \\}
        \\type Callable = {
        \\  (value: string): string;
        \\  value: string;
        \\  (value: number): number;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_adjacent_overload_signatures.id));
}

test "does not report @typescript-eslint/adjacent-overload-signatures for adjacent overloads" {
    const source =
        \\function parse(value: string): string;
        \\function parse(value: number): number;
        \\function parse(value: string | number): string | number {
        \\  return value;
        \\}
        \\class Example {
        \\  method(value: string): string;
        \\  method(value: number): number;
        \\  method(value: string | number): string | number {
        \\    return value;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_adjacent_overload_signatures.id));
}

test "can disable @typescript-eslint/adjacent-overload-signatures" {
    const source =
        \\function parse(value: string): string;
        \\function other(value: string): string;
        \\function parse(value: number): number;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_adjacent_overload_signatures = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_adjacent_overload_signatures.id));
}
