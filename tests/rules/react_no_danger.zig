const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-danger on DOM JSX elements" {
    const source =
        \\const node = <div dangerouslySetInnerHTML={{ __html: html }} />;
        \\const path = <svg:path dangerouslySetInnerHTML={{ __html: html }} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_no_danger.id));
    try std.testing.expectEqualStrings("Dangerous property 'dangerouslySetInnerHTML' found", result.diagnostics[0].message);
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "does not report react/no-danger on custom JSX components by default" {
    const source =
        \\const node = <Widget dangerouslySetInnerHTML={{ __html: html }} />;
        \\const member = <Widget.Inner dangerouslySetInnerHTML={{ __html: html }} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_danger.id));
}

test "can disable react/no-danger" {
    const source =
        \\const node = <div dangerouslySetInnerHTML={{ __html: html }} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .react_no_danger = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_danger.id));
}
