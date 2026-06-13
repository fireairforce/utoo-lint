const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports jsx-a11y/aria-proptypes invalid values by type" {
    const source =
        \\const one = <div aria-hidden="mixed" />;
        \\const two = <div aria-label />;
        \\const three = <div aria-level="abc" />;
        \\const four = <div aria-current="foo" />;
        \\const five = <div aria-relevant="additions foo" />;
        \\const six = <div aria-checked="maybe" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.jsx_a11y_aria_proptypes.id));
    try std.testing.expect(hasMessage(result, "The value for aria-hidden must be a boolean."));
    try std.testing.expect(hasMessage(result, "The value for aria-label must be a string."));
    try std.testing.expect(hasMessage(result, "The value for aria-level must be a integer."));
    try std.testing.expect(hasMessage(result, "The value for aria-current must be a single token from the following: page,step,location,date,time,true,false."));
    try std.testing.expect(hasMessage(result, "The value for aria-relevant must be a list of one or more tokens from the following: additions,all,removals,text."));
    try std.testing.expect(hasMessage(result, "The value for aria-checked must be a boolean or the string \"mixed\"."));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/aria-proptypes valid values and dynamic values" {
    const source =
        \\const one = <div aria-hidden />;
        \\const two = <div aria-hidden="true" />;
        \\const three = <div aria-label="hello" />;
        \\const four = <div aria-checked="mixed" />;
        \\const five = <div aria-level="1.5" />;
        \\const six = <div aria-current="page" />;
        \\const seven = <div aria-current={true} />;
        \\const eight = <div aria-controls="a b" />;
        \\const nine = <div aria-controls={id} />;
        \\const ten = <div aria-controls={null} />;
        \\const eleven = <div aria-relevant="additions text" />;
        \\const twelve = <div aria-label={`${name}`} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_aria_proptypes.id));
}

test "ignores jsx-a11y/aria-proptypes invalid aria attributes" {
    const source =
        \\const node = <div aria-foo="bar" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_aria_props = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_aria_proptypes.id));
}

test "can disable jsx-a11y/aria-proptypes" {
    const source =
        \\const node = <div aria-hidden="mixed" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_aria_proptypes = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_aria_proptypes.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_aria_proptypes.id)) return diagnostic;
    }
    return null;
}

fn hasMessage(result: lint.Result, message: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, message)) return true;
    }
    return false;
}
