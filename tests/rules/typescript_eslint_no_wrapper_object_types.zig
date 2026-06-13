const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-wrapper-object-types for built-in wrapper object types" {
    const source =
        \\let text: String;
        \\let flag: Boolean;
        \\let count: Number;
        \\let big: BigInt;
        \\let sym: Symbol;
        \\let value: Object;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_ban_types = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.typescript_eslint_no_wrapper_object_types.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_wrapper_object_types.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report primitives, lowercase object, Function, or qualified names" {
    const source =
        \\let text: string;
        \\let flag: boolean;
        \\let count: number;
        \\let big: bigint;
        \\let sym: symbol;
        \\let value: object;
        \\let fn: Function;
        \\let namespaced: NS.String;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_ban_types = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_wrapper_object_types.id));
}

test "does not duplicate @typescript-eslint/ban-types diagnostics for wrapper object types" {
    const source =
        \\let text: String;
        \\let fn: Function;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_wrapper_object_types.id));
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_ban_types.id));
}

test "can disable @typescript-eslint/no-wrapper-object-types" {
    const source =
        \\let text: String;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_wrapper_object_types = false,
        .typescript_eslint_ban_types = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_wrapper_object_types.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_ban_types.id));
}
