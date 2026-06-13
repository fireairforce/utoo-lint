const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-invalid-void-type for invalid void positions" {
    const source =
        \\type Alias = void;
        \\type ArrayVoid = void[];
        \\type UnionVoid = string | void;
        \\interface Shape {
        \\  value: void;
        \\}
        \\function takesVoid(value: void) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.typescript_eslint_no_invalid_void_type.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_invalid_void_type.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "allows @typescript-eslint/no-invalid-void-type valid void positions" {
    const source =
        \\function returnsVoid(): void {}
        \\const arrow = (): void => {};
        \\type FunctionType = () => void;
        \\type ConstructorType = new () => void;
        \\type PromiseVoid = Promise<void>;
        \\interface Callable {
        \\  value(): void;
        \\  prop: () => void;
        \\  (): void;
        \\  new (): void;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_invalid_void_type.id));
}

test "reports @typescript-eslint/no-invalid-void-type for void in unions inside type arguments" {
    const source =
        \\type PromiseUnion = Promise<string | void>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_invalid_void_type.id));
}

test "can disable @typescript-eslint/no-invalid-void-type" {
    const source =
        \\type Alias = void;
        \\type UnionVoid = string | void;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_no_invalid_void_type = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_invalid_void_type.id));
}
