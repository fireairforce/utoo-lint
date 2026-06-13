const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-dupe-class-members for duplicate members" {
    const source =
        \\class Example {
        \\  value() {}
        \\  value() {}
        \\  field = 1;
        \\  field = 2;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_dupe_class_members.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_dupe_class_members.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_dupe_class_members.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/no-dupe-class-members for getter setter pairs" {
    const source =
        \\class Example {
        \\  get value() { return this.x; }
        \\  set value(next) { this.x = next; }
        \\  value2() {}
        \\  static value2() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_dupe_class_members.id));
}

test "can disable @typescript-eslint/no-dupe-class-members and fall back to core rule" {
    const source =
        \\class Example {
        \\  value() {}
        \\  value() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_dupe_class_members = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_dupe_class_members.id));
    try std.testing.expect(helpers.hasRule(result, lint.rules.no_dupe_class_members.id));
}
