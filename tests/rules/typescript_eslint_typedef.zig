const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/typedef for unannotated type properties" {
    const source =
        \\declare const key: unique symbol;
        \\interface InterfaceShape {
        \\  value;
        \\  optional?;
        \\  readonly readonlyValue;
        \\  [key];
        \\  "literal";
        \\}
        \\type TypeShape = {
        \\  value;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.typescript_eslint_typedef.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_typedef.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "allows @typescript-eslint/typedef annotated properties and non-property declarations" {
    const source =
        \\interface InterfaceShape {
        \\  value: string;
        \\  method(): void;
        \\}
        \\type TypeShape = {
        \\  value: number;
        \\};
        \\class Example {
        \\  value = 1;
        \\}
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_typedef.id));
}

test "can disable @typescript-eslint/typedef" {
    const source =
        \\interface InterfaceShape {
        \\  value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_typedef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_typedef.id));
}
