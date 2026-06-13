const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/restrict-plus-operands for mixed and invalid primitive operands" {
    const source =
        \\const count: number = 1;
        \\const label: string = "items";
        \\const enabled: boolean = true;
        \\const mystery: unknown = 1;
        \\count + label;
        \\enabled + count;
        \\mystery + count;
        \\1 + "x";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.typescript_eslint_restrict_plus_operands.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_restrict_plus_operands.id)) {
            try std.testing.expectEqual(lint.Severity.warning, diagnostic.severity);
        }
    }
}

test "allows @typescript-eslint/restrict-plus-operands compatible primitive operands" {
    const source =
        \\const left: number = 1;
        \\const right: number = 2;
        \\const first: string = "a";
        \\const second: string = "b";
        \\left + right;
        \\first + second;
        \\(1 as number) + <number>2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_restrict_plus_operands.id));
}

test "can disable @typescript-eslint/restrict-plus-operands" {
    const source =
        \\const count: number = 1;
        \\const label: string = "items";
        \\count + label;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_restrict_plus_operands = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_restrict_plus_operands.id));
}
