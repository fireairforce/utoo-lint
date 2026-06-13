const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/explicit-member-accessibility for public class members" {
    const source =
        \\class Service {
        \\  public constructor() {}
        \\  public start(): void {}
        \\  public get size(): number {
        \\    return 1;
        \\  }
        \\  public value = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.typescript_eslint_explicit_member_accessibility.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_explicit_member_accessibility.id)) {
            try std.testing.expectEqual(lint.Severity.warning, diagnostic.severity);
        }
    }
}

test "allows @typescript-eslint/explicit-member-accessibility non-public and omitted accessibility" {
    const source =
        \\class Service {
        \\  constructor(public readonly id: string) {}
        \\  start(): void {}
        \\  private stop(): void {}
        \\  protected restart(): void {}
        \\  value = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_explicit_member_accessibility.id));
}

test "can disable @typescript-eslint/explicit-member-accessibility" {
    const source =
        \\class Service {
        \\  public start(): void {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_explicit_member_accessibility = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_explicit_member_accessibility.id));
}
