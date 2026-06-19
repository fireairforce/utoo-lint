const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports jsx-a11y/alt-text for missing and invalid alternatives" {
    const source =
        \\const one = <img />;
        \\const two = <img role="presentation" />;
        \\const three = <img alt />;
        \\const four = <img aria-label="" />;
        \\const five = <area />;
        \\const six = <object />;
        \\const seven = <input type="image" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.jsx_a11y_alt_text.id));
    try std.testing.expect(hasMessage(result, "img elements must have an alt prop, either with meaningful text, or an empty string for decorative images."));
    try std.testing.expect(hasMessage(result, "Prefer alt=\"\" over a presentational role. First rule of aria is to not use aria if it can be achieved via native HTML."));
    try std.testing.expect(hasMessage(result, "Invalid alt value for img. Use alt=\"\" for presentational images."));
    try std.testing.expect(hasMessage(result, "The aria-label attribute must have a value. The alt attribute is preferred over aria-label for images."));
    try std.testing.expect(hasMessage(result, "Each area of an image map must have a text alternative through the `alt`, `aria-label`, or `aria-labelledby` prop."));
    try std.testing.expect(hasMessage(result, "Embedded <object> elements must have alternative text by providing inner text, aria-label or aria-labelledby props."));
    try std.testing.expect(hasMessage(result, "<input> elements with type=\"image\" must have a text alternative through the `alt`, `aria-label`, or `aria-labelledby` prop."));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/alt-text valid alternatives and non matching elements" {
    const source =
        \\const one = <img alt="" />;
        \\const two = <img alt="text" />;
        \\const three = <img aria-label="label" />;
        \\const four = <img aria-labelledby="id" />;
        \\const five = <area alt="" />;
        \\const six = <area aria-label="label" />;
        \\const seven = <object title="title" />;
        \\const eight = <object>text</object>;
        \\const nine = <object aria-labelledby="id" />;
        \\const ten = <input type="image" alt="submit" />;
        \\const eleven = <input type="text" />;
        \\const twelve = <input type={kind} />;
        \\const thirteen = <Img />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_alt_text.id));
}

test "supports configured jsx-a11y/alt-text elements and components" {
    var elements_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"elements\":[\"img\"]}]",
        .{},
    );
    defer elements_config.deinit();

    var elements_options = lint.Options{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try elements_options.setByRuleConfigValue("jsx-a11y/alt-text", elements_config.value);

    var elements_result = try lint.lintSource(std.testing.allocator,
        \\const one = <img />;
        \\const two = <area />;
        \\const three = <object />;
        \\const four = <input type="image" />;
    , "fixture.tsx", elements_options);
    defer elements_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(elements_result, lint.rules.jsx_a11y_alt_text.id));

    var components_config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"img\":[\"Image\"],\"object\":[\"ObjectEmbed\"],\"area\":[\"MapArea\"],\"input[type=\\\"image\\\"]\":[\"InputImage\"]}]",
        .{},
    );
    defer components_config.deinit();

    var components_options = lint.Options{
        .eol_last = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try components_options.setByRuleConfigValue("jsx-a11y/alt-text", components_config.value);

    var components_result = try lint.lintSource(std.testing.allocator,
        \\const one = <Image />;
        \\const two = <ObjectEmbed />;
        \\const three = <MapArea />;
        \\const four = <InputImage />;
        \\const five = <Avatar />;
    , "fixture.tsx", components_options);
    defer components_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(components_result, lint.rules.jsx_a11y_alt_text.id));
    try std.testing.expect(hasMessage(components_result, "Image elements must have an alt prop, either with meaningful text, or an empty string for decorative images."));
}

test "can disable jsx-a11y/alt-text" {
    const source =
        \\const node = <img />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_alt_text = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_alt_text.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_alt_text.id)) return diagnostic;
    }
    return null;
}

fn hasMessage(result: lint.Result, message: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, message)) return true;
    }
    return false;
}
