const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/no-typos for static property casing" {
    const source =
        \\class View extends React.Component {
        \\  static proptypes = {
        \\    name: PropTypes.string,
        \\  };
        \\  static DefaultProps = {};
        \\}
        \\View.contexttypes = {};
        \\createReactClass({
        \\  proptypes: {
        \\    name: PropTypes.string,
        \\  },
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.react_no_typos.id));
    try std.testing.expect(hasMessage(result, "Typo in static class property declaration"));
    try std.testing.expect(hasMessage(result, "Typo in property declaration"));
}

test "reports react/no-typos for prop type misspellings" {
    const source =
        \\import PropTypes from 'prop-types';
        \\class View extends React.Component {
        \\  static propTypes = {
        \\    name: PropTypes.strng,
        \\    age: PropTypes.number.isRequiredd,
        \\    shape: PropTypes.shape({
        \\      nested: PropTypes.boool,
        \\    }),
        \\    either: PropTypes.oneOfType([
        \\      PropTypes.string,
        \\      PropTypes.numer,
        \\    ]),
        \\  };
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.react_no_typos.id));
    try std.testing.expect(hasMessage(result, "Typo in declared prop type: strng"));
    try std.testing.expect(hasMessage(result, "Typo in prop type chain qualifier: isRequiredd"));
    try std.testing.expect(hasMessage(result, "Typo in declared prop type: boool"));
    try std.testing.expect(hasMessage(result, "Typo in declared prop type: numer"));
}

test "reports react/no-typos for lifecycle method casing and static lifecycle" {
    const source =
        \\class View extends React.Component {
        \\  componentdidMount() {}
        \\  getderivedstatefromprops() {}
        \\}
        \\createReactClass({
        \\  componentwillUnmount() {},
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.react_no_typos.id));
    try std.testing.expect(hasMessage(result, "Typo in component lifecycle method declaration: componentdidMount should be componentDidMount"));
    try std.testing.expect(hasMessage(result, "Lifecycle method should be static: getderivedstatefromprops"));
    try std.testing.expect(hasMessage(result, "Typo in component lifecycle method declaration: getderivedstatefromprops should be getDerivedStateFromProps"));
    try std.testing.expect(hasMessage(result, "Typo in component lifecycle method declaration: componentwillUnmount should be componentWillUnmount"));
}

test "reports react/no-typos for missing import bindings" {
    const source =
        \\import 'react';
        \\import 'prop-types';
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_no_typos.id));
    try std.testing.expect(hasMessage(result, "`'react'` imported without a local `React` binding."));
    try std.testing.expect(hasMessage(result, "`'prop-types'` imported without a local `PropTypes` binding."));
}

test "allows react/no-typos for correctly cased declarations" {
    const source =
        \\import PropTypes from 'prop-types';
        \\class View extends React.Component {
        \\  static propTypes = {
        \\    name: PropTypes.string.isRequired,
        \\    shape: PropTypes.exact({
        \\      nested: PropTypes.bool,
        \\    }),
        \\  };
        \\  static defaultProps = {};
        \\  static getDerivedStateFromProps() {}
        \\  componentDidMount() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_typos.id));
}

test "can disable react/no-typos" {
    const source =
        \\class View extends React.Component {
        \\  componentdidMount() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_no_typos = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_no_typos.id));
}

fn hasMessage(result: lint.Result, expected: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.message, expected)) return true;
    }
    return false;
}
