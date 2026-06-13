const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const message = "<iframe> elements must have a unique title property.";

test "reports jsx-a11y/iframe-has-title for iframe without valid title" {
    const source =
        \\const one = <iframe />;
        \\const two = <iframe title />;
        \\const three = <iframe title="" />;
        \\const four = <iframe title={false} />;
        \\const five = <iframe title={0} />;
        \\const six = <iframe title={null} />;
        \\const seven = <iframe title={undefined} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.jsx_a11y_iframe_has_title.id));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings(message, diagnostic.message);
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/iframe-has-title valid titles and non-iframes" {
    const source =
        \\const one = <iframe title="Account summary" />;
        \\const two = <iframe title={label} />;
        \\const three = <iframe title={`Embedded ${name}`} />;
        \\const four = <Frame title="" />;
        \\const five = <div />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_iframe_has_title.id));
}

test "can disable jsx-a11y/iframe-has-title" {
    const source =
        \\const node = <iframe />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_iframe_has_title = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_iframe_has_title.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_iframe_has_title.id)) return diagnostic;
    }
    return null;
}
