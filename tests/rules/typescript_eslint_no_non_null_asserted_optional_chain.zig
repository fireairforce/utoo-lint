const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-non-null-asserted-optional-chain for asserted optional chains" {
    const source =
        \\(foo?.bar)!;
        \\foo?.bar!;
        \\(foo?.())!;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_no_non_null_asserted_optional_chain.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_non_null_asserted_optional_chain.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/no-non-null-asserted-optional-chain for inner chain assertions" {
    const source =
        \\foo?.bar!.baz;
        \\foo?.bar!.baz();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_non_null_asserted_optional_chain.id));
}

test "can disable @typescript-eslint/no-non-null-asserted-optional-chain" {
    const source =
        \\foo?.bar!;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_non_null_asserted_optional_chain = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_non_null_asserted_optional_chain.id));
}
