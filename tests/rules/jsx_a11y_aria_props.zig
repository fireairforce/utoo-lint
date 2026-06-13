const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports jsx-a11y/aria-props for invalid aria attributes" {
    const source =
        \\const one = <div aria-foo="x" />;
        \\const two = <div aria-labeledby="x" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.jsx_a11y_aria_props.id));
    try std.testing.expect(hasMessage(result, "aria-foo: This attribute is an invalid ARIA attribute."));
    try std.testing.expect(hasMessage(result, "aria-labeledby: This attribute is an invalid ARIA attribute. Did you mean to use aria-labelledby?"));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/aria-props valid aria attributes and non aria props" {
    const source =
        \\const one = <div aria-label="Name" aria-labelledby="id" aria-activedescendant="item" />;
        \\const two = <div ariaLabel="Name" aria="ignored" data-aria-foo="x" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_aria_props.id));
}

test "can disable jsx-a11y/aria-props" {
    const source =
        \\const node = <div aria-foo="x" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_aria_props = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_aria_props.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_aria_props.id)) return diagnostic;
    }
    return null;
}

fn hasMessage(result: lint.Result, message: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, message)) return true;
    }
    return false;
}
