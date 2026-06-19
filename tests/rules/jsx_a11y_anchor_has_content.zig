const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const message = "Anchors must have content and the content must be accessible by a screen reader.";

test "reports jsx-a11y/anchor-has-content for empty anchors" {
    const source =
        \\const one = <a />;
        \\const two = <a></a>;
        \\const three = <a>{undefined}</a>;
        \\const four = <a><span aria-hidden /></a>;
        \\const five = <a><input type="hidden" /></a>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.jsx_a11y_anchor_has_content.id));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings(message, diagnostic.message);
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/anchor-has-content accessible content and labels" {
    const source =
        \\const one = <a>text</a>;
        \\const two = <a>{text}</a>;
        \\const three = <a>{false}</a>;
        \\const four = <a><span /></a>;
        \\const five = <a title="x" />;
        \\const six = <a aria-label="x" />;
        \\const seven = <a dangerouslySetInnerHTML={{ __html: html }} />;
        \\const eight = <a children="text" />;
        \\const nine = <A />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_anchor_has_content.id));
}

test "supports configured jsx-a11y/anchor-has-content components" {
    const source =
        \\const one = <Anchor />;
        \\const two = <Anchor>text</Anchor>;
        \\const three = <Link />;
        \\const four = <a />;
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer default_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.jsx_a11y_anchor_has_content.id));

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"components\":[\"Anchor\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("jsx-a11y/anchor-has-content", config.value);

    var configured_result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", options);
    defer configured_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(configured_result, lint.rules.jsx_a11y_anchor_has_content.id));
}

test "can disable jsx-a11y/anchor-has-content" {
    const source =
        \\const node = <a />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_anchor_has_content = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_anchor_has_content.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_anchor_has_content.id)) return diagnostic;
    }
    return null;
}
