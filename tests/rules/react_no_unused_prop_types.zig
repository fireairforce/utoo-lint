const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn noUnusedPropTypesOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.react_no_unused_prop_types = true;
    return options;
}

test "reports react/no-unused-prop-types for unused prop type declarations" {
    const source =
        \\import React from 'react';
        \\function Foo(props) {
        \\  return <div>{props.name}</div>;
        \\}
        \\Foo.propTypes = {
        \\  name: PropTypes.string,
        \\  age: PropTypes.number,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", noUnusedPropTypesOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_no_unused_prop_types.id));
    try std.testing.expect(std.mem.eql(u8, result.diagnostics[0].message, "'age' PropType is defined but prop is never used"));
}

test "skips react/no-unused-prop-types shape props for fishlint configuration" {
    const source =
        \\import React from 'react';
        \\function Foo(props) {
        \\  return <div>{props.name}</div>;
        \\}
        \\Foo.propTypes = {
        \\  name: PropTypes.string,
        \\  user: PropTypes.shape({
        \\    age: PropTypes.number,
        \\  }),
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", noUnusedPropTypesOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_unused_prop_types.id));
}

test "reports react/no-unused-prop-types object props" {
    const source =
        \\import React from 'react';
        \\function Foo(props) {
        \\  return <div>{props.name}</div>;
        \\}
        \\Foo.propTypes = {
        \\  name: PropTypes.string,
        \\  user: PropTypes.object,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", noUnusedPropTypesOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_no_unused_prop_types.id));
    try std.testing.expect(std.mem.eql(u8, result.diagnostics[0].message, "'user' PropType is defined but prop is never used"));
}

test "reports react/no-unused-prop-types for class components" {
    const source =
        \\import React from 'react';
        \\class Foo extends React.Component {
        \\  render() {
        \\    return <div>{this.props.name}</div>;
        \\  }
        \\}
        \\Foo.propTypes = {
        \\  name: PropTypes.string,
        \\  age: PropTypes.number,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", noUnusedPropTypesOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_no_unused_prop_types.id));
    try std.testing.expect(std.mem.eql(u8, result.diagnostics[0].message, "'age' PropType is defined but prop is never used"));
}

test "can disable react/no-unused-prop-types" {
    const source =
        \\import React from 'react';
        \\function Foo(props) {
        \\  return <div>{props.name}</div>;
        \\}
        \\Foo.propTypes = {
        \\  name: PropTypes.string,
        \\  age: PropTypes.number,
        \\};
    ;

    var options = noUnusedPropTypesOnly();
    options.react_no_unused_prop_types = false;
    var result = try lint.lintSource(std.testing.allocator, source, "sample.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_unused_prop_types.id));
}
