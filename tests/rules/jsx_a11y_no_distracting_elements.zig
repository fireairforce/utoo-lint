const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports jsx-a11y/no-distracting-elements for marquee and blink" {
    const source =
        \\const one = <marquee />;
        \\const two = <blink />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.jsx_a11y_no_distracting_elements.id));
    try std.testing.expect(hasMessage(result, "Do not use <marquee> elements as they can create visual accessibility issues and are deprecated."));
    try std.testing.expect(hasMessage(result, "Do not use <blink> elements as they can create visual accessibility issues and are deprecated."));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/no-distracting-elements non distracting and custom components" {
    const source =
        \\const one = <div />;
        \\const two = <Marquee />;
        \\const three = <Blink />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_no_distracting_elements.id));
}

test "supports configured jsx-a11y/no-distracting-elements elements" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"elements\":[\"blink\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("jsx-a11y/no-distracting-elements", config.value);

    const source =
        \\const one = <marquee />;
        \\const two = <blink />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.jsx_a11y_no_distracting_elements.id));
    try std.testing.expect(!hasMessage(result, "Do not use <marquee> elements as they can create visual accessibility issues and are deprecated."));
    try std.testing.expect(hasMessage(result, "Do not use <blink> elements as they can create visual accessibility issues and are deprecated."));
}

test "can disable jsx-a11y/no-distracting-elements" {
    const source =
        \\const node = <marquee />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_no_distracting_elements = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_no_distracting_elements.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_no_distracting_elements.id)) return diagnostic;
    }
    return null;
}

fn hasMessage(result: lint.Result, message: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, message)) return true;
    }
    return false;
}
