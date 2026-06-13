const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const message = "No access key attribute allowed. Inconsistencies between keyboard shortcuts and keyboard commands used by screen readers and keyboard-only users create a11y complications.";

test "reports jsx-a11y/no-access-key for truthy accessKey attributes" {
    const source =
        \\const one = <div accessKey="n" />;
        \\const two = <Button accesskey />;
        \\const three = <span accessKey={1} />;
        \\const four = <span accessKey={shortcut} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.jsx_a11y_no_access_key.id));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings(message, diagnostic.message);
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/no-access-key falsy or absent values" {
    const source =
        \\const one = <div />;
        \\const two = <div accessKey="" />;
        \\const three = <div accessKey={false} />;
        \\const four = <div accessKey={0} />;
        \\const five = <div accessKey={null} />;
        \\const six = <div accessKey={undefined} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_no_access_key.id));
}

test "can disable jsx-a11y/no-access-key" {
    const source =
        \\const node = <div accessKey="n" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_no_access_key = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_no_access_key.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_no_access_key.id)) return diagnostic;
    }
    return null;
}
