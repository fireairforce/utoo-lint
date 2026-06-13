const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/jsx-no-duplicate-props for repeated JSX props" {
    const source =
        \\const node = <Widget name="a" Name="b" enabled enabled={true} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .react_jsx_boolean_value = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_jsx_no_duplicate_props.id));
    try std.testing.expectEqualStrings("No duplicate props allowed", result.diagnostics[0].message);
}

test "ignores spread attributes and distinct JSX props" {
    const source =
        \\const node = <Widget {...props} name="a" label="b" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_no_duplicate_props.id));
}

test "can disable react/jsx-no-duplicate-props" {
    const source =
        \\const node = <Widget name="a" name="b" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .react_jsx_no_duplicate_props = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_no_duplicate_props.id));
}
