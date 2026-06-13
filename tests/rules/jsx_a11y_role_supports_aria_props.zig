const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports jsx-a11y/role-supports-aria-props for explicit and implicit roles" {
    const source =
        \\const one = <div role="button" aria-checked="true" />;
        \\const two = <button aria-checked="true" />;
        \\const three = <input type="checkbox" aria-valuenow={1} />;
        \\const four = <h1 aria-checked="true" />;
        \\const five = <img alt="x" aria-checked="true" />;
        \\const six = <input type="range" aria-checked="true" />;
        \\const seven = <div role={`button`} aria-checked="true" />;
        \\const eight = <div role="button" aria-checked={foo} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 8), helpers.countRule(result, lint.rules.jsx_a11y_role_supports_aria_props.id));
    try std.testing.expect(hasMessage(result, "The attribute aria-checked is not supported by the role button."));
    try std.testing.expect(hasMessage(result, "The attribute aria-checked is not supported by the role button. This role is implicit on the element button."));
    try std.testing.expect(hasMessage(result, "The attribute aria-valuenow is not supported by the role checkbox. This role is implicit on the element input."));
    try std.testing.expect(hasMessage(result, "The attribute aria-checked is not supported by the role heading. This role is implicit on the element h1."));
    try std.testing.expect(hasMessage(result, "The attribute aria-checked is not supported by the role img. This role is implicit on the element img."));
    try std.testing.expect(hasMessage(result, "The attribute aria-checked is not supported by the role slider. This role is implicit on the element input."));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/role-supports-aria-props supported roles and ignored values" {
    const source =
        \\const one = <div role="button" aria-pressed="true" />;
        \\const two = <button aria-pressed="true" />;
        \\const three = <div aria-checked="true" />;
        \\const four = <div role="notarole" aria-checked="true" />;
        \\const five = <div role={role} aria-checked="true" />;
        \\const six = <div role="checkbox" aria-checked={undefined} />;
        \\const seven = <div role="checkbox" aria-checked={null} />;
        \\const eight = <div role="checkbox" aria-valuenow={null} />;
        \\const nine = <img alt="" aria-checked="true" />;
        \\const ten = <img src="x.svg" aria-checked="true" />;
        \\const eleven = <Foo role="button" aria-pressed="true" />;
        \\const twelve = <div role="button checkbox" aria-checked="true" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_jsx_no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_role_supports_aria_props.id));
}

test "can disable jsx-a11y/role-supports-aria-props" {
    const source =
        \\const node = <div role="button" aria-checked="true" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_role_supports_aria_props = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_role_supports_aria_props.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_role_supports_aria_props.id)) return diagnostic;
    }
    return null;
}

fn hasMessage(result: lint.Result, message: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, message)) return true;
    }
    return false;
}
