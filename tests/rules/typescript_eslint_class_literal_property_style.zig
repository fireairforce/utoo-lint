const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/class-literal-property-style for literal getters" {
    const source =
        \\class Example {
        \\  get name() {
        \\    return "fish";
        \\  }
        \\  static get count() {
        \\    return 1;
        \\  }
        \\  get enabled() {
        \\    return true;
        \\  }
        \\  get pattern() {
        \\    return /fish/;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.typescript_eslint_class_literal_property_style.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_class_literal_property_style.id)) {
            try std.testing.expectEqual(lint.Severity.warning, diagnostic.severity);
        }
    }
}

test "allows @typescript-eslint/class-literal-property-style non-literal and non-single-return getters" {
    const source =
        \\declare function compute(): string;
        \\class Example {
        \\  get name() {
        \\    return compute();
        \\  }
        \\  get object() {
        \\    return {};
        \\  }
        \\  get multiple() {
        \\    const value = "fish";
        \\    return value;
        \\  }
        \\  value() {
        \\    return "fish";
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_class_literal_property_style.id));
}

test "can disable @typescript-eslint/class-literal-property-style" {
    const source =
        \\class Example {
        \\  get name() {
        \\    return "fish";
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .typescript_eslint_class_literal_property_style = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_class_literal_property_style.id));
}
