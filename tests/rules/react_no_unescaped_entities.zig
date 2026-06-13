const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-unescaped-entities for default JSX text entities" {
    const source =
        \\const node = <div>Tom's "quote" > brace }</div>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.react_no_unescaped_entities.id));
    try std.testing.expectEqualStrings("`'` can be escaped with `&apos;`, `&lsquo;`, `&#39;`, `&rsquo;`.", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("`\"` can be escaped with `&quot;`, `&ldquo;`, `&#34;`, `&rdquo;`.", result.diagnostics[1].message);
    try std.testing.expectEqualStrings("`>` can be escaped with `&gt;`.", result.diagnostics[3].message);
    try std.testing.expectEqualStrings("`}` can be escaped with `&#125;`.", result.diagnostics[4].message);
}

test "allows escaped entities and JavaScript expression strings" {
    const source =
        \\const text = "Tom's > brace }";
        \\const node = <div>Tom&apos;s &quot;quote&quot; &gt; brace &#125; {"}"}</div>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_unescaped_entities.id));
}

test "can disable react/no-unescaped-entities" {
    const source =
        \\const node = <div>Tom's ></div>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_no_unescaped_entities = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_unescaped_entities.id));
}
