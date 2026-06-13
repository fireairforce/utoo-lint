const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const test_options = lint.Options{
    .no_undef = false,
    .no_unused_vars = false,
    .typescript_eslint_no_unused_vars = false,
    .react_jsx_no_undef = false,
};

test "reports React class render methods without return" {
    const source =
        \\import { Component } from "react";
        \\class A extends React.Component {
        \\  render() {
        \\    const node = <div />;
        \\  }
        \\}
        \\class B extends React.PureComponent {
        \\  render() {}
        \\}
        \\class C extends React.Component {
        \\  render = () => {
        \\    const node = <div />;
        \\  };
        \\}
        \\class D extends Component {
        \\  render() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.react_require_render_return.id));
}

test "allows React class render methods with return" {
    const source =
        \\class A extends React.Component {
        \\  render() {
        \\    if (ready) {
        \\      return <Ready />;
        \\    }
        \\    return null;
        \\  }
        \\}
        \\class B extends React.PureComponent {
        \\  render = () => <div />;
        \\}
        \\class C extends React.Component {
        \\  render = function () {
        \\    return <div />;
        \\  };
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_require_render_return.id));
}

test "reports createReactClass render methods without return" {
    const source =
        \\const A = createReactClass({
        \\  render() {
        \\    const node = <div />;
        \\  }
        \\});
        \\const B = React.createClass({
        \\  render: function () {}
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_require_render_return.id));
}

test "allows non-components and createReactClass render returns" {
    const source =
        \\class A extends View {
        \\  render() {}
        \\}
        \\const B = createReactClass({
        \\  render: () => <div />,
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", test_options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_require_render_return.id));
}

test "can disable react require render return" {
    const source =
        \\class A extends React.Component {
        \\  render() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .react_jsx_no_undef = false,
        .react_require_render_return = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_require_render_return.id));
}
