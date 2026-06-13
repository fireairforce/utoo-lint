const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/array-type for simple generic array types" {
    const source =
        \\type Names = Array<string>;
        \\type Values = ReadonlyArray<number>;
        \\type Nested = Array<string[]>;
        \\type Qualified = Array<Foo.Bar>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.typescript_eslint_array_type.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_array_type.id)) {
            try std.testing.expectEqual(lint.Severity.warning, diagnostic.severity);
        }
    }
}

test "reports @typescript-eslint/array-type for non-simple shorthand array types" {
    const source =
        \\type Union = (string | number)[];
        \\type Callable = (() => void)[];
        \\type ObjectLiteral = { name: string }[];
        \\type Tuple = [string, number][];
        \\type Keyed = Foo["bar"][];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.typescript_eslint_array_type.id));
}

test "allows @typescript-eslint/array-type compliant array-simple forms" {
    const source =
        \\type Names = string[];
        \\type Nested = string[][];
        \\type Union = Array<string | number>;
        \\type Callable = Array<() => void>;
        \\type Generic = Array<Promise<string>>;
        \\type Readonly = readonly string[];
        \\type Parenthesized = (string)[];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_array_type.id));
}

test "can disable @typescript-eslint/array-type" {
    const source =
        \\type Names = Array<string>;
        \\type Union = (string | number)[];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_array_type = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_array_type.id));
}
