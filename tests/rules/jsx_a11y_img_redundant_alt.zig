const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const message = "Redundant alt attribute. Screen-readers already announce `img` tags as an image. You don’t need to use the words `image`, `photo,` or `picture` (or any specified custom words) in the alt prop.";

test "reports jsx-a11y/img-redundant-alt for redundant img alt text" {
    const source =
        \\const one = <img alt="photo of user" />;
        \\const two = <img alt={"IMAGE"} />;
        \\const three = <img alt={`picture`} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.jsx_a11y_img_redundant_alt.id));
    const diagnostic = findDiagnostic(result) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings(message, diagnostic.message);
    try std.testing.expectEqual(.warning, diagnostic.severity);
}

test "allows jsx-a11y/img-redundant-alt non-redundant hidden or dynamic alt text" {
    const source =
        \\const one = <img alt="portrait of user" />;
        \\const two = <img alt="" />;
        \\const three = <img alt={label} />;
        \\const four = <img aria-hidden="true" alt="image" />;
        \\const five = <img aria-hidden={true} alt="photo" />;
        \\const six = <area alt="picture map" />;
        \\const seven = <input type="image" alt="image button" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_img_redundant_alt.id));
}

test "can disable jsx-a11y/img-redundant-alt" {
    const source =
        \\const node = <img alt="image" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", .{
        .eol_last = false,
        .jsx_a11y_img_redundant_alt = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.jsx_a11y_img_redundant_alt.id));
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.jsx_a11y_img_redundant_alt.id)) return diagnostic;
    }
    return null;
}
