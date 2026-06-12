const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-useless-constructor for empty and pass-through constructors" {
    const source =
        \\class Empty {
        \\  constructor() {}
        \\}
        \\class Derived extends Base {
        \\  constructor(...args: unknown[]) {
        \\    super(...args);
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_useless_constructor.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_constructor.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_useless_constructor.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/no-useless-constructor for useful TypeScript constructors" {
    const source =
        \\class ParameterProperty {
        \\  constructor(public value: string) {}
        \\}
        \\class ProtectedConstructor {
        \\  protected constructor() {}
        \\}
        \\class PublicDerived extends Base {
        \\  public constructor() {
        \\    super();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_useless_constructor.id));
}

test "can disable @typescript-eslint/no-useless-constructor and fall back to core rule" {
    const source =
        \\class Empty {
        \\  constructor() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_useless_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_useless_constructor.id));
    try std.testing.expect(helpers.hasRule(result, lint.rules.no_useless_constructor.id));
}
