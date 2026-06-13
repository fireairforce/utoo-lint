const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/consistent-type-assertions for angle bracket assertions" {
    const source =
        \\declare const input: unknown;
        \\const value = <string>input;
        \\const objectValue = <Foo>{ x: 1 };
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_consistent_type_assertions.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_consistent_type_assertions.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "reports @typescript-eslint/consistent-type-assertions for object literal as assertions" {
    const source =
        \\const value = { x: 1 } as Foo;
        \\const nested = ({ x: 1 }) as Foo;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_consistent_type_assertions.id));
}

test "allows @typescript-eslint/consistent-type-assertions compliant assertions" {
    const source =
        \\declare const input: unknown;
        \\const value = input as string;
        \\const objectValue = { x: 1 } as const;
        \\const arrayValue = [1] as Foo;
        \\const functionValue = (() => 1) as Foo;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_consistent_type_assertions.id));
}

test "can disable @typescript-eslint/consistent-type-assertions" {
    const source =
        \\declare const input: unknown;
        \\const value = <string>input;
        \\const objectValue = { x: 1 } as Foo;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_consistent_type_assertions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_consistent_type_assertions.id));
}
