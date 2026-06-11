const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-template-curly-in-string for template-looking text in strings" {
    const source =
        \\const first = "Hello ${name}";
        \\const second = 'Total: ${amount}';
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_template_curly_in_string.id));
}

test "does not report no-template-curly-in-string for templates or incomplete text" {
    const source =
        \\const template = `Hello ${name}`;
        \\const dollar = "Price is $5";
        \\const open = "Hello ${name";
        \\const braces = "Hello {name}";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_template_curly_in_string.id));
}

test "can disable no-template-curly-in-string" {
    const source =
        \\const first = "Hello ${name}";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_template_curly_in_string = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_template_curly_in_string.id));
}
