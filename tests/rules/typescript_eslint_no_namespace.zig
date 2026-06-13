const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-namespace for non-declare namespaces and modules" {
    const source =
        \\namespace Internal {
        \\  export const value = 1;
        \\}
        \\module Legacy {
        \\  export const value = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_prefer_namespace_keyword = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_namespace.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_namespace.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "allows declare namespaces and modules" {
    const source =
        \\declare namespace Internal {
        \\  export const value: number;
        \\}
        \\declare module "external" {
        \\  export const value: number;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_prefer_namespace_keyword = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_namespace.id));
}

test "allows namespaces in definition files" {
    const source =
        \\namespace Internal {
        \\  export const value: number;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.d.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_prefer_namespace_keyword = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_namespace.id));
}

test "can disable @typescript-eslint/no-namespace" {
    const source =
        \\namespace Internal {
        \\  export const value = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_namespace = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_namespace.id));
}
