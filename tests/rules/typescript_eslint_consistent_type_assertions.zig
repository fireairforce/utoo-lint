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

test "reports @typescript-eslint/consistent-type-assertions for as assertions in angle bracket mode" {
    const source =
        \\declare const input: unknown;
        \\const value = input as string;
        \\const objectValue = { x: 1 } as const;
        \\const angleValue = <string>input;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_consistent_type_assertions_assertion_style = .angle_bracket,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_consistent_type_assertions.id));
    try std.testing.expect(hasMessage(result, "Use '<string>' instead of 'as string'."));
}

test "reports @typescript-eslint/consistent-type-assertions for all assertions in never mode" {
    const source =
        \\declare const input: unknown;
        \\const asValue = input as string;
        \\const angleValue = <string>input;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_consistent_type_assertions_assertion_style = .never,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_consistent_type_assertions.id));
    try std.testing.expect(hasMessage(result, "Do not use type assertions."));
}

test "allows @typescript-eslint/consistent-type-assertions object literal parameter assertions" {
    const source =
        \\declare function use(value: Foo): void;
        \\declare class Box {
        \\  constructor(value: Foo);
        \\}
        \\use({ x: 1 } as Foo);
        \\new Box(({ x: 1 }) as Foo);
        \\const value = { x: 1 } as Foo;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_consistent_type_assertions_object_literal_type_assertions = .allow_as_parameter,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_consistent_type_assertions.id));
    try std.testing.expect(hasMessage(result, "Always prefer const x: T = { ... }."));
}

test "reports @typescript-eslint/consistent-type-assertions array literal assertions" {
    const source =
        \\const value = [1] as Foo;
        \\const objectValue = { x: 1 } as Foo;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_consistent_type_assertions_object_literal_type_assertions = .allow,
        .typescript_eslint_consistent_type_assertions_array_literal_type_assertions = .never,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_consistent_type_assertions.id));
    try std.testing.expect(hasMessage(result, "Always prefer const x: T = [ ... ]."));
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

fn hasMessage(result: lint.Result, expected: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, expected)) return true;
    }
    return false;
}
