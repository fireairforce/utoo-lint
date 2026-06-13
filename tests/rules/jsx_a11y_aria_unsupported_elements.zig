const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports jsx-a11y/aria-unsupported-elements for aria and role on reserved elements" {
    const source =
        \\const one = <meta aria-hidden="true" />;
        \\const two = <script role="button" />;
        \\const three = <style ARIA-LABEL="theme" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.jsx_a11y_aria_unsupported_elements.id));
    try std.testing.expect(hasMessage(result, "This element does not support ARIA roles, states and properties. Try removing the prop 'aria-hidden'."));
    try std.testing.expect(hasMessage(result, "This element does not support ARIA roles, states and properties. Try removing the prop 'role'."));
    try std.testing.expect(hasMessage(result, "This element does not support ARIA roles, states and properties. Try removing the prop 'aria-label'."));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/aria-unsupported-elements supported and invalid aria props" {
    const source =
        \\const one = <div aria-hidden="true" role="button" />;
        \\const two = <Meta aria-hidden="true" />;
        \\const three = <meta aria-foo="bar" />;
        \\const four = <meta data-id="bar" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_aria_props = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_aria_unsupported_elements.id));
}

test "can disable jsx-a11y/aria-unsupported-elements" {
    const source =
        \\const node = <meta aria-hidden="true" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_aria_unsupported_elements = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_aria_unsupported_elements.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_aria_unsupported_elements.id)) return diagnostic;
    }
    return null;
}

fn hasMessage(result: lint.Result, message: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, message)) return true;
    }
    return false;
}
