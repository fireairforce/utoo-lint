const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/prefer-es6-class for createReactClass components" {
    const source =
        \\const A = createReactClass({
        \\  render() {
        \\    return <div />;
        \\  }
        \\});
        \\const B = React.createReactClass({
        \\  render() {
        \\    return <span />;
        \\  }
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_no_danger_with_children = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_prefer_es6_class.id));
    try std.testing.expectEqualStrings(
        "Component should use es6 class instead of createClass",
        result.diagnostics[0].message,
    );
}

test "allows non-component objects and default React.createClass" {
    const source =
        \\const obj = { render() { return <div />; } };
        \\const legacy = React.createClass({
        \\  render() {
        \\    return <div />;
        \\  }
        \\});
        \\const nested = factory({ render() { return <div />; } });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_no_danger_with_children = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_prefer_es6_class.id));
}

test "can disable react/prefer-es6-class" {
    const source =
        \\const A = createReactClass({
        \\  render() {
        \\    return <div />;
        \\  }
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_prefer_es6_class = false,
        .react_no_danger_with_children = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_prefer_es6_class.id));
}
