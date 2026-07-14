const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports new-parens for constructors without parentheses" {
    const source =
        \\const first = new Widget;
        \\const second = new namespace.Widget;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.new_parens.id));
}

test "does not report new-parens when parentheses or arguments are present" {
    const source =
        \\const first = new Widget();
        \\const second = new Widget(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.new_parens.id));
}

test "can disable new-parens" {
    const source =
        \\const first = new Widget;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .new_parens = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.new_parens.id));
}

test "autofixes constructors missing parentheses" {
    const source =
        \\const first = new Widget;
        \\const second = new namespace.Widget;
    ;
    const expected =
        \\const first = new Widget();
        \\const second = new namespace.Widget();
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.new_parens.id));
}

test "autofixes each constructor in a nested new expression" {
    const source = "const value = new new Widget;";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("const value = new new Widget()();", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.new_parens.id));
}
