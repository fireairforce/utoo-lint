const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-duplicate-enum-values for repeated literal enum values" {
    const source =
        \\enum Status {
        \\  Pending = "pending",
        \\  Waiting = "pending",
        \\  Started = 1,
        \\  AlsoStarted = 1,
        \\  DecimalStarted = 1.0,
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_no_duplicate_enum_values.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_duplicate_enum_values.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "ignores implicit and computed enum initializers" {
    const source =
        \\const value = 1;
        \\enum Status {
        \\  First,
        \\  Second,
        \\  Computed = value,
        \\  AlsoComputed = value,
        \\  Expression = 1 + 1,
        \\  AlsoExpression = 1 + 1,
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_duplicate_enum_values.id));
}

test "can disable @typescript-eslint/no-duplicate-enum-values" {
    const source =
        \\enum Status {
        \\  Pending = "pending",
        \\  Waiting = "pending",
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_duplicate_enum_values = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_duplicate_enum_values.id));
}
