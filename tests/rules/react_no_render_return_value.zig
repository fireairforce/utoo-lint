const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-render-return-value when ReactDOM.render result is used" {
    const source =
        \\const mount = ReactDOM.render(node, container);
        \\target = ReactDOM.render(node, container);
        \\function mountNode() {
        \\  return ReactDOM.render(node, container);
        \\}
        \\const mountArrow = () => ReactDOM.render(node, container);
        \\const object = { mount: ReactDOM.render(node, container) };
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.react_no_render_return_value.id));
    try std.testing.expectEqualStrings(
        "Do not depend on the return value from ReactDOM.render",
        result.diagnostics[0].message,
    );
}

test "ignores standalone render calls and non-ReactDOM render calls" {
    const source =
        \\ReactDOM.render(node, container);
        \\React.render(node, container);
        \\Renderer.render(node, container);
        \\use(ReactDOM.render(node, container));
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_render_return_value.id));
}

test "can disable react/no-render-return-value" {
    const source =
        \\const mount = ReactDOM.render(node, container);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_no_render_return_value = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_render_return_value.id));
}
