const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn defaultPropsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.react_default_props_match_prop_types = true;
    return options;
}

test "reports react/default-props-match-prop-types for missing and required propTypes" {
    const source =
        \\function Foo() {
        \\  return <div />;
        \\}
        \\Foo.propTypes = {
        \\  name: PropTypes.string.isRequired,
        \\  age: PropTypes.number,
        \\};
        \\Foo.defaultProps = {
        \\  name: "Ada",
        \\  extra: true,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", defaultPropsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.react_default_props_match_prop_types.id));
    try std.testing.expectEqualStrings(
        "defaultProp \"name\" defined for isRequired propType.",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqualStrings(
        "defaultProp \"extra\" has no corresponding propTypes declaration.",
        result.diagnostics[1].message,
    );
}

test "supports configured react/default-props-match-prop-types allowRequiredDefaults" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowRequiredDefaults\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("react/default-props-match-prop-types", config.value);

    const source =
        \\function Foo() {
        \\  return <div />;
        \\}
        \\Foo.propTypes = {
        \\  name: PropTypes.string.isRequired,
        \\  age: PropTypes.number,
        \\};
        \\Foo.defaultProps = {
        \\  name: "Ada",
        \\  extra: true,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_default_props_match_prop_types.id));
    try std.testing.expectEqualStrings(
        "defaultProp \"extra\" has no corresponding propTypes declaration.",
        result.diagnostics[0].message,
    );
}

test "can disable react/default-props-match-prop-types" {
    const source =
        \\function Foo() {
        \\  return <div />;
        \\}
        \\Foo.propTypes = {
        \\  name: PropTypes.string.isRequired,
        \\};
        \\Foo.defaultProps = {
        \\  name: "Ada",
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .react_default_props_match_prop_types = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_default_props_match_prop_types.id));
}
