const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/member-ordering for fishlint class member order" {
    const source =
        \\class Example {
        \\  method() {}
        \\  field = 1;
        \\  private static privateValue = 1;
        \\  public static publicValue = 1;
        \\  constructor() {}
        \\  lateField = 2;
        \\  protected protectedMethod() {}
        \\  public publicMethod() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_empty_block_statements = false,
        .typescript_eslint_explicit_member_accessibility = false,
        .typescript_eslint_no_empty_function = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.typescript_eslint_member_ordering.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_member_ordering.id)) {
            try std.testing.expectEqual(lint.Severity.warning, diagnostic.severity);
        }
    }
}

test "allows @typescript-eslint/member-ordering correct fishlint order" {
    const source =
        \\class Example {
        \\  public static publicValue = 1;
        \\  protected static protectedValue = 1;
        \\  private static privateValue = 1;
        \\  public static publicMethod() {}
        \\  field = 1;
        \\  constructor() {}
        \\  public method() {}
        \\  protected protectedMethod() {}
        \\  private privateMethod() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_empty_block_statements = false,
        .typescript_eslint_explicit_member_accessibility = false,
        .typescript_eslint_no_empty_function = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_member_ordering.id));
}

test "can disable @typescript-eslint/member-ordering" {
    const source =
        \\class Example {
        \\  method() {}
        \\  field = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_member_ordering = false,
        .no_empty_block_statements = false,
        .typescript_eslint_explicit_member_accessibility = false,
        .typescript_eslint_no_empty_function = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_member_ordering.id));
}
