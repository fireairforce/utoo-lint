const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const message = "The scope prop can only be used on <th> elements.";

test "reports jsx-a11y/scope for scope on non-th dom elements" {
    const source =
        \\const one = <div scope="row" />;
        \\const two = <td scope="col" />;
        \\const three = <span SCOPE />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.jsx_a11y_scope.id));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings(message, diagnostic.message);
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/scope on th and custom components" {
    const source =
        \\const one = <th scope="row" />;
        \\const two = <Th scope="row" />;
        \\const three = <Custom scope="row" />;
        \\const four = <foo scope="row" />;
        \\const five = <td />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_scope.id));
}

test "can disable jsx-a11y/scope" {
    const source =
        \\const node = <div scope="row" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_scope = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_scope.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_scope.id)) return diagnostic;
    }
    return null;
}
