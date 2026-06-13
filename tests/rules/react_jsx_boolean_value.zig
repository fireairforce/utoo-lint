const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/jsx-boolean-value for explicit true boolean attributes" {
    const source =
        \\const node = <Widget disabled={true} required={true} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_jsx_boolean_value.id));
    try std.testing.expectEqualStrings("Value must be omitted for boolean attribute `disabled`", result.diagnostics[0].message);
}

test "allows omitted false and non-boolean JSX attribute values" {
    const source =
        \\const node = <Widget disabled checked={false} label="ok" count={1} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_boolean_value.id));
}

test "can disable react/jsx-boolean-value" {
    const source =
        \\const node = <Widget disabled={true} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .react_jsx_boolean_value = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_boolean_value.id));
}
