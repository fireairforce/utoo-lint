const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/display-name for anonymous component definitions" {
    const source =
        \\export default class extends React.Component {
        \\  render() { return <div />; }
        \\}
        \\export const View = React.memo(() => <span />);
        \\export const Named = React.forwardRef(function NamedRef() { return <div />; });
        \\module.exports = React.createClass({
        \\  render() { return <div />; },
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_display_name.id));
    try std.testing.expect(hasMessage(result, "Component definition is missing display name"));
}

test "allows react/display-name for transpiler names and explicit displayName" {
    const source =
        \\class ClassView extends React.Component {
        \\  render() { return <div />; }
        \\}
        \\export default class WithStaticName extends React.Component {
        \\  static displayName = 'WithStaticName';
        \\  render() { return <div />; }
        \\}
        \\function FunctionView() {
        \\  return <div />;
        \\}
        \\const ArrowView = () => <div />;
        \\const WrappedView = React.memo(() => <div />);
        \\WrappedView.displayName = 'WrappedView';
        \\const CreatedView = React.createClass({
        \\  render() { return <div />; },
        \\});
        \\module.exports = React.createClass({
        \\  displayName: 'LegacyView',
        \\  render() { return <div />; },
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_display_name.id));
}

test "tracks react/display-name assignments before component definitions" {
    const source =
        \\Assigned.displayName = 'Assigned';
        \\const Assigned = React.memo(() => <div />);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_display_name.id));
}

test "supports configured react/display-name checkContextObjects" {
    const source =
        \\const MissingContext = React.createContext(null);
        \\const NamedContext = createContext(null);
        \\NamedContext.displayName = 'NamedContext';
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"checkContextObjects\":true}]",
        .{},
    );
    defer config.deinit();

    var options = baseOptions();
    try options.setByRuleConfigValue("react/display-name", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_display_name.id));
    try std.testing.expect(hasMessage(result, "Component definition is missing display name"));
}

test "allows react/display-name context objects by default" {
    const source =
        \\const ThemeContext = React.createContext(null);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_display_name.id));
}

test "can disable react/display-name" {
    const source =
        \\export default () => <div />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_display_name = false,
        .react_jsx_no_undef = false,
        .react_jsx_uses_react = false,
        .react_jsx_uses_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_display_name.id));
}

fn baseOptions() lint.Options {
    return .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_jsx_no_undef = false,
        .react_jsx_uses_react = false,
        .react_jsx_uses_vars = false,
    };
}

fn hasMessage(result: lint.Result, expected: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.react_display_name.id) and
            std.mem.eql(u8, diagnostic.message, expected))
        {
            return true;
        }
    }
    return false;
}
