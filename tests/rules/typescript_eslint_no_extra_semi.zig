const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-extra-semi for unnecessary empty statements" {
    const source =
        \\const value = 1;;
        \\function run() {}
        \\;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_empty_function = false,
        .typescript_eslint_no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_extra_semi.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_semi.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_extra_semi.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/no-extra-semi for empty statement bodies" {
    const source =
        \\while (ready);
        \\for (; ready; );
        \\if (ready); else ;
        \\label: ;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_labels = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_extra_semi.id));
}

test "can disable @typescript-eslint/no-extra-semi and fall back to core rule" {
    const source =
        \\const value = 1;;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_extra_semi = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_extra_semi.id));
    try std.testing.expect(helpers.hasRule(result, lint.rules.no_extra_semi.id));
}

test "autofixes @typescript-eslint/no-extra-semi diagnostics" {
    const source = "const value = 1;;";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    var fixed = try lint.applyFixes(std.testing.allocator, source, result.diagnostics);
    defer fixed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("const value = 1;", fixed.output);
}
