const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports jsx-a11y/role-has-required-aria-props missing required props" {
    const source =
        \\const one = <div role="checkbox" />;
        \\const two = <div role="heading" />;
        \\const three = <div role="heading checkbox" />;
        \\const four = <div role="combobox" aria-controls="id" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.jsx_a11y_role_has_required_aria_props.id));
    try std.testing.expect(hasMessage(result, "Elements with the ARIA role \"checkbox\" must have the following attributes defined: aria-checked"));
    try std.testing.expect(hasMessage(result, "Elements with the ARIA role \"heading\" must have the following attributes defined: aria-level"));
    try std.testing.expect(hasMessage(result, "Elements with the ARIA role \"combobox\" must have the following attributes defined: aria-controls,aria-expanded"));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/role-has-required-aria-props satisfied dynamic and semantic cases" {
    const source =
        \\const one = <div role="checkbox" aria-checked="false" />;
        \\const two = <div role="combobox" aria-controls="id" aria-expanded="false" />;
        \\const three = <Foo role="checkbox" />;
        \\const four = <div role={role} />;
        \\const five = <input type="checkbox" role="switch" />;
        \\const six = <div role="button" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_role_has_required_aria_props.id));
}

test "can disable jsx-a11y/role-has-required-aria-props" {
    const source =
        \\const node = <div role="checkbox" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_role_has_required_aria_props = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_role_has_required_aria_props.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_role_has_required_aria_props.id)) return diagnostic;
    }
    return null;
}

fn hasMessage(result: lint.Result, message: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, message)) return true;
    }
    return false;
}
