const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/method-signature-style for shorthand method signatures" {
    const source =
        \\interface Service {
        \\  start(): void;
        \\  optional?<T>(value: T): T;
        \\}
        \\type Handler = {
        \\  run(input: string): void;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_method_signature_style.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_method_signature_style.id)) {
            try std.testing.expectEqual(lint.Severity.warning, diagnostic.severity);
        }
    }
}

test "allows @typescript-eslint/method-signature-style property and non-method signatures" {
    const source =
        \\interface Service {
        \\  start: () => void;
        \\  (): void;
        \\  new (): Service;
        \\  get size(): number;
        \\}
        \\type Handler = {
        \\  run: (input: string) => void;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_method_signature_style.id));
}

test "can disable @typescript-eslint/method-signature-style" {
    const source =
        \\interface Service {
        \\  start(): void;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_method_signature_style = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_method_signature_style.id));
}
