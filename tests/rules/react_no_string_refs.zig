const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-string-refs for string ref attributes" {
    const source =
        \\const direct = <div ref="root" />;
        \\const expression = <div ref={"root"} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_no_string_refs.id));
    try std.testing.expectEqualStrings(
        "Using string literals in ref attributes is deprecated.",
        result.diagnostics[0].message,
    );
}

test "allows non-string refs and default template literals" {
    const source =
        \\const callback = <div ref={(node) => node} />;
        \\const objectRef = <div ref={ref} />;
        \\const template = <div ref={`root`} />;
        \\const other = <div data-ref="root" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_string_refs.id));
}

test "supports configured react/no-string-refs noTemplateLiterals" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"noTemplateLiterals\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("react/no-string-refs", config.value);

    const source =
        \\const template = <div ref={`root`} />;
        \\const dynamic = <div ref={`root-${id}`} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_no_string_refs.id));
}

test "can disable react/no-string-refs" {
    const source =
        \\const direct = <div ref="root" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_no_string_refs = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_string_refs.id));
}
