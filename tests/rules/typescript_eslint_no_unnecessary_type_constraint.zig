const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-unnecessary-type-constraint for any and unknown" {
    const source =
        \\type AnyBox<T extends any> = T;
        \\interface UnknownBox<T extends unknown> {
        \\  value: T;
        \\}
        \\type Defaulted<T extends unknown = string> = T;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_no_unnecessary_type_constraint.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_unnecessary_type_constraint.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/no-unnecessary-type-constraint for useful constraints" {
    const source =
        \\type StringBox<T extends string> = T;
        \\interface KeyBox<T extends keyof Props> {
        \\  value: T;
        \\}
        \\type Unconstrained<T> = T;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unnecessary_type_constraint.id));
}

test "can disable @typescript-eslint/no-unnecessary-type-constraint" {
    const source =
        \\type AnyBox<T extends any> = T;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unnecessary_type_constraint = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_unnecessary_type_constraint.id));
}
