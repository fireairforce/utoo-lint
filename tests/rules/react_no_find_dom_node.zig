const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-find-dom-node for direct and member calls" {
    const source =
        \\findDOMNode(node);
        \\ReactDOM.findDOMNode(node);
        \\React.findDOMNode(node);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_no_find_dom_node.id));
    try std.testing.expectEqualStrings(
        "Do not use findDOMNode. It doesn't work with function components and is deprecated in StrictMode. See https://reactjs.org/docs/react-dom.html#finddomnode",
        result.diagnostics[0].message,
    );
}

test "ignores other calls and computed property access" {
    const source =
        \\findDomNode(node);
        \\ReactDOM.render(node);
        \\ReactDOM["findDOMNode"](node);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_find_dom_node.id));
}

test "can disable react/no-find-dom-node" {
    const source =
        \\ReactDOM.findDOMNode(node);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_no_find_dom_node = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_find_dom_node.id));
}
