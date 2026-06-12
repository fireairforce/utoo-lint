const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/prefer-namespace-keyword for custom module declarations" {
    const source =
        \\module Internal {
        \\  export const value = 1;
        \\}
        \\declare module Declared {
        \\  export const value: number;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_prefer_namespace_keyword.id));
}

test "does not report @typescript-eslint/prefer-namespace-keyword for namespace or ambient string modules" {
    const source =
        \\namespace Internal {
        \\  export const value = 1;
        \\}
        \\declare module "external" {
        \\  export const value: number;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_prefer_namespace_keyword.id));
}

test "can disable @typescript-eslint/prefer-namespace-keyword" {
    const source =
        \\module Internal {
        \\  export const value = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_prefer_namespace_keyword = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_prefer_namespace_keyword.id));
}
