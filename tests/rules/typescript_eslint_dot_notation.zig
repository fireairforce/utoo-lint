const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/dot-notation for computed string properties" {
    const source =
        \\object["property"];
        \\object["_private"];
        \\object["$value"];
        \\object["property1"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.typescript_eslint_dot_notation.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.dot_notation.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_dot_notation.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/dot-notation when bracket access is required" {
    const source =
        \\object["not-valid"];
        \\object["123"];
        \\object[""];
        \\object[property];
        \\object[call()];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_dot_notation.id));
}

test "can disable @typescript-eslint/dot-notation and fall back to core rule" {
    const source =
        \\object["property"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_dot_notation.id));
    try std.testing.expect(helpers.hasRule(result, lint.rules.dot_notation.id));
}
