const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const message = "Elements with ARIA roles must use a valid, non-abstract ARIA role.";

test "reports jsx-a11y/aria-role for invalid and abstract roles" {
    const source =
        \\const one = <div role="foo" />;
        \\const two = <span role="widget" />;
        \\const three = <section role="button foo" />;
        \\const four = <div role />;
        \\const five = <div role={null} />;
        \\const six = <div role={false} />;
        \\const seven = <div role={`${name}`} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.jsx_a11y_aria_role.id));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings(message, diagnostic.message);
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/aria-role valid roles and non-dom elements" {
    const source =
        \\const one = <div role="button" />;
        \\const two = <span role="button link" />;
        \\const three = <div role={`button`} />;
        \\const four = <Foo role="foo" />;
        \\const five = <Div role="foo" />;
        \\const six = <foo role="foo" />;
        \\const seven = <div role={role} />;
        \\const eight = <div role={undefined} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_aria_role.id));
}

test "can disable jsx-a11y/aria-role" {
    const source =
        \\const node = <div role="foo" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_aria_role = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_aria_role.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_aria_role.id)) return diagnostic;
    }
    return null;
}
