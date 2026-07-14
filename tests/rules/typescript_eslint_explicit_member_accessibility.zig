const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "does not enable @typescript-eslint/explicit-member-accessibility by default" {
    const source =
        \\class Service {
        \\  public start(): void {}
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
        .typescript_eslint_explicit_member_accessibility = true,
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
        .typescript_eslint_explicit_member_accessibility = true,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_explicit_member_accessibility.id));
}

test "reports @typescript-eslint/explicit-member-accessibility explicit mode for omitted accessibility" {
    const source =
        \\class Service {
        \\  constructor() {}
        \\  public start(): void {}
        \\  private stop(): void {}
        \\  get size(): number {
        \\    return 1;
        \\  }
        \\  value = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_explicit_member_accessibility = true,
        .typescript_eslint_explicit_member_accessibility_accessibility = .explicit,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_explicit_member_accessibility.id));
    try std.testing.expect(hasMessage(result, "Missing accessibility modifier on method definition constructor."));
    try std.testing.expect(hasMessage(result, "Missing accessibility modifier on get property accessor size."));
    try std.testing.expect(hasMessage(result, "Missing accessibility modifier on class property value."));
}

test "allows @typescript-eslint/explicit-member-accessibility accessibility off mode" {
    const source =
        \\class Service {
        \\  public start(): void {}
        \\  value = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_explicit_member_accessibility = true,
        .typescript_eslint_explicit_member_accessibility_accessibility = .off,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_explicit_member_accessibility.id));
}

fn hasMessage(result: lint.Result, expected: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, expected)) return true;
    }
    return false;
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
